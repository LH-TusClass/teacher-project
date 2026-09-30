<template>
  <div v-if="!store.currentClassId" class="empty-wrap">
    <el-empty description="请先在「班级管理」中创建并选择一个班级">
      <el-button type="primary" @click="$router.push('/classes')">去创建班级</el-button>
    </el-empty>
  </div>

  <div v-else class="card roster-card">
    <!-- 工具栏（打印时隐藏） -->
    <div class="toolbar no-print">
      <el-input v-model="keyword" placeholder="搜索姓名 / 学号" clearable style="width: 220px" :prefix-icon="Search" />
      <el-radio-group v-model="genderFilter">
        <el-radio-button value="">全部</el-radio-button>
        <el-radio-button value="男">男</el-radio-button>
        <el-radio-button value="女">女</el-radio-button>
      </el-radio-group>
      <el-select v-model="sortBy" style="width: 160px">
        <el-option label="按学号排序" value="no" />
        <el-option label="按姓名排序" value="name" />
      </el-select>
      <el-button @click="doPrint">🖨️ 打印花名册</el-button>
      <el-button :disabled="!filtered.length" @click="exportXlsx">📤 导出 Excel</el-button>
    </div>

    <!-- 打印头部 -->
    <div class="print-header">
      <h2>{{ store.currentClass?.name || '班级' }} 花名册</h2>
      <div class="print-meta">
        共 {{ filtered.length }} 人 · 男 {{ maleCount }} 人 · 女 {{ femaleCount }} 人
        <span class="no-print" style="color: #909399">（点击学生姓名可查看历次成绩）</span>
      </div>
    </div>

    <!-- 统计卡片（打印时隐藏） -->
    <div class="stat-row no-print" v-if="students.length">
      <div class="stat-box">
        <div class="stat-num">{{ students.length }}</div>
        <div class="stat-label">总人数</div>
      </div>
      <div class="stat-box">
        <div class="stat-num" style="color: #409eff">{{ maleCount }}</div>
        <div class="stat-label">男生（{{ malePct }}%）</div>
      </div>
      <div class="stat-box">
        <div class="stat-num" style="color: #f56c6c">{{ femaleCount }}</div>
        <div class="stat-label">女生（{{ femalePct }}%）</div>
      </div>
      <div class="stat-box">
        <div class="stat-num" style="color: #e6a23c">{{ exams.length }}</div>
        <div class="stat-label">已记录考试</div>
      </div>
    </div>

    <!-- 花名册表格 -->
    <table class="roster-table" v-loading="loading">
      <thead>
        <tr>
          <th style="width: 60px">序号</th>
          <th style="width: 130px">学号</th>
          <th style="width: 110px">姓名</th>
          <th style="width: 70px">性别</th>
          <th>备注</th>
          <th style="width: 110px">家长签名</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(s, i) in filtered" :key="s.id">
          <td>{{ i + 1 }}</td>
          <td>{{ s.studentNo || '-' }}</td>
          <td>
            <a class="name-link" @click="openDetail(s)">{{ s.name }}</a>
          </td>
          <td>{{ s.gender || '-' }}</td>
          <td></td>
          <td></td>
        </tr>
      </tbody>
      <tbody v-if="!filtered.length && !loading">
        <tr>
          <td colspan="6" class="roster-empty">{{ students.length ? '没有符合条件的学生' : '暂无学生，请先在「学生管理」中录入' }}</td>
        </tr>
      </tbody>
    </table>
  </div>

  <!-- 学生历次成绩抽屉 -->
  <el-drawer v-model="detailVisible" :title="detailStudent ? `${detailStudent.name} · 历次成绩` : ''" size="520px">
    <template v-if="detailStudent">
      <div v-if="!detailRows.length" class="empty-wrap" style="padding: 40px 0">
        <el-empty description="该学生暂无考试成绩" />
      </div>
      <el-table v-else :data="detailRows" border size="small">
        <el-table-column prop="examName" label="考试" min-width="120" />
        <el-table-column v-for="sub in detailSubjects" :key="sub" :label="sub" width="80" align="center">
          <template #default="{ row }">
            <span :class="scoreClass(row.scores[sub])">{{ row.scores[sub] ?? '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="总分" width="80" align="center">
          <template #default="{ row }">
            <b>{{ row.total ?? '-' }}</b>
          </template>
        </el-table-column>
        <el-table-column label="班名次" width="75" align="center">
          <template #default="{ row }">
            <el-tag v-if="row.rank" :type="row.rank <= 3 ? 'warning' : 'info'" size="small">{{ row.rank }}</el-tag>
            <span v-else style="color: #c0c4cc">-</span>
          </template>
        </el-table-column>
      </el-table>
    </template>
  </el-drawer>
</template>

<script setup>
import { ref, computed, watch } from 'vue';
import { ElMessage } from 'element-plus';
import { Search } from '@element-plus/icons-vue';
import * as XLSX from 'xlsx';
import { api } from '../api';
import { store } from '../store';

const students = ref([]);
const exams = ref([]);
const loading = ref(false);

const keyword = ref('');
const genderFilter = ref('');
const sortBy = ref('no');

const detailVisible = ref(false);
const detailStudent = ref(null);

async function load() {
  if (!store.currentClassId) {
    students.value = [];
    exams.value = [];
    return;
  }
  loading.value = true;
  try {
    const [stus, exs] = await Promise.all([
      api.get(`/students?classId=${store.currentClassId}`),
      api.get(`/exams?classId=${store.currentClassId}`),
    ]);
    students.value = stus;
    exams.value = [...exs].sort((a, b) => (a.date || '').localeCompare(b.date || ''));
  } catch (e) {
    ElMessage.error(e.message);
  } finally {
    loading.value = false;
  }
}
watch(() => store.currentClassId, load, { immediate: true });

const filtered = computed(() => {
  const kw = keyword.value.trim();
  let list = students.value.filter((s) => {
    if (genderFilter.value && s.gender !== genderFilter.value) return false;
    if (kw && !(s.name.includes(kw) || (s.studentNo || '').includes(kw))) return false;
    return true;
  });
  list = [...list];
  if (sortBy.value === 'no') {
    list.sort((a, b) => (a.studentNo || 'zzz').localeCompare(b.studentNo || 'zzz', 'zh'));
  } else {
    list.sort((a, b) => a.name.localeCompare(b.name, 'zh'));
  }
  return list;
});

const maleCount = computed(() => students.value.filter((s) => s.gender === '男').length);
const femaleCount = computed(() => students.value.filter((s) => s.gender === '女').length);
const total2 = maleCount.value + femaleCount.value;
const malePct = total2 ? Math.round((maleCount.value / total2) * 100) : 0;
const femalePct = total2 ? 100 - malePct : 0;

/* ---------- 学生历次成绩 ---------- */

const detailSubjects = computed(() => {
  if (!detailStudent.value) return [];
  const set = new Set();
  for (const e of exams.value) {
    if (e.scores?.[detailStudent.value.id]) (e.subjects || []).forEach((s) => set.add(s));
  }
  return [...set];
});

const detailRows = computed(() => {
  const sid = detailStudent.value?.id;
  if (!sid) return [];
  return exams.value
    .filter((e) => e.scores?.[sid])
    .map((e) => {
      const sc = e.scores[sid];
      const total = (e.subjects || []).reduce((sum, sub) => sum + (Number(sc[sub]) || 0), 0);
      return { examName: e.name, scores: sc, total: Math.round(total * 100) / 100 };
    })
    .map((row) => ({ ...row, rank: rankOf(detailStudent.value.id, row.examName) }));
});

function rankOf(sid, examName) {
  const exam = exams.value.find((e) => e.name === examName);
  if (!exam) return null;
  const totals = [];
  for (const [id, sc] of Object.entries(exam.scores || {})) {
    if (!sc) continue;
    const t = (exam.subjects || []).reduce((sum, sub) => sum + (Number(sc[sub]) || 0), 0);
    totals.push({ id, t });
  }
  totals.sort((a, b) => b.t - a.t);
  const idx = totals.findIndex((x) => x.id === sid);
  return idx >= 0 ? idx + 1 : null;
}

function openDetail(s) {
  detailStudent.value = s;
  detailVisible.value = true;
}

function scoreClass(v) {
  if (v === undefined || v === null || v === '') return 'muted';
  const n = Number(v);
  if (n >= 85) return 'good';
  if (n < 60) return 'bad';
  return '';
}

/* ---------- 打印 / 导出 ---------- */

function doPrint() {
  window.print();
}

function exportXlsx() {
  if (!filtered.value.length) return;
  const data = filtered.value.map((s, i) => ({ 序号: i + 1, 学号: s.studentNo, 姓名: s.name, 性别: s.gender }));
  const ws = XLSX.utils.json_to_sheet(data);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, '花名册');
  XLSX.writeFile(wb, `${store.currentClass?.name || '班级'}-花名册.xlsx`);
}
</script>

<style scoped>
.roster-card { padding: 18px; }
.print-header { text-align: center; margin: 6px 0 16px; }
.print-header h2 { margin: 0 0 6px; font-size: 20px; }
.print-meta { color: #606266; font-size: 14px; }

.stat-row { display: flex; gap: 14px; margin-bottom: 16px; }
.stat-box {
  flex: 1; text-align: center; padding: 14px 0;
  background: #f5f7fa; border-radius: 8px;
}
.stat-num { font-size: 26px; font-weight: 700; color: #303133; }
.stat-label { font-size: 12px; color: #909399; margin-top: 4px; }

.roster-table { width: 100%; border-collapse: collapse; font-size: 14px; }
.roster-table th, .roster-table td {
  border: 1px solid #dcdfe6; padding: 8px 12px; text-align: left;
}
.roster-table thead th { background: #f5f7fa; font-weight: 600; color: #303133; }
.roster-empty { text-align: center; color: #909399; padding: 32px 0; }
.name-link { color: #409eff; cursor: pointer; }
.name-link:hover { text-decoration: underline; }

.good { color: #67c23a; font-weight: 600; }
.bad { color: #f56c6c; font-weight: 600; }
.muted { color: #c0c4cc; }

@media print {
  .roster-card { box-shadow: none; border: none; padding: 0; }
}
</style>
