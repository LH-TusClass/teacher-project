<template>
  <div v-if="!store.currentClassId" class="empty-wrap">
    <el-empty description="请先在「班级管理」中创建并选择一个班级">
      <el-button type="primary" @click="$router.push('/classes')">去创建班级</el-button>
    </el-empty>
  </div>

  <div v-else class="card">
    <div class="toolbar">
      <span>考试：</span>
      <el-select v-model="examId" style="width: 240px" placeholder="选择考试">
        <el-option v-for="e in exams" :key="e.id" :label="e.name" :value="e.id" />
      </el-select>

      <el-radio-group v-model="metric" :disabled="!exam">
        <el-radio-button v-if="exam" value="__total__">总分</el-radio-button>
        <el-radio-button v-for="sub in exam?.subjects || []" :key="sub" :value="sub">{{ sub }}</el-radio-button>
      </el-radio-group>

      <el-button :disabled="!ranked.length" @click="exportCsv">📤 导出 CSV</el-button>
      <span class="count">{{ ranked.length }} 人参与排名</span>
    </div>

    <!-- 加权设置（仅总分模式） -->
    <div v-if="exam && metric === '__total__'" class="toolbar" style="background: #f8f9fb; border-radius: 6px; padding: 10px 12px">
      <span style="color: #909399">科目权重：</span>
      <div v-for="sub in exam.subjects" :key="sub" style="display: flex; align-items: center; gap: 4px">
        <span style="font-size: 13px">{{ sub }}</span>
        <el-input-number v-model="weights[sub]" :min="0" :max="10" :step="0.1" :precision="1" size="small" style="width: 100px" />
      </div>
      <span style="color: #c0c4cc; font-size: 12px">总分 = Σ(科目成绩 × 权重)，默认全部为 1</span>
    </div>

    <el-table v-if="exam" :data="ranked" stripe v-loading="loading">
      <el-table-column label="排名" width="100" align="center">
        <template #default="{ row }">
          <span v-if="row.rank === 1">🥇 1</span>
          <span v-else-if="row.rank === 2">🥈 2</span>
          <span v-else-if="row.rank === 3">🥉 3</span>
          <span v-else style="font-weight: 600">{{ row.rank }}</span>
        </template>
      </el-table-column>
      <el-table-column prop="name" label="姓名" width="140" />
      <el-table-column prop="studentNo" label="学号" width="140">
        <template #default="{ row }">{{ row.studentNo || '-' }}</template>
      </el-table-column>
      <el-table-column v-for="sub in exam.subjects" :key="sub" :label="sub" width="110" align="center">
        <template #default="{ row }">
          <span :style="metric === sub ? 'font-weight: 700; color: #409eff' : ''">{{ row.sc[sub] ?? '-' }}</span>
        </template>
      </el-table-column>
      <el-table-column label="加权总分" width="120" align="center">
        <template #default="{ row }">
          <span :style="metric === '__total__' ? 'font-weight: 700; color: #409eff' : ''">{{ row.total }}</span>
        </template>
      </el-table-column>
      <template #empty>
        <el-empty description="该考试暂无成绩，请先到「成绩管理」录入" />
      </template>
    </el-table>
    <el-empty v-else-if="!loading" description="还没有考试数据，请先到「成绩管理」创建考试并录入成绩" />
  </div>
</template>

<script setup>
import { ref, computed, watch, reactive } from 'vue';
import { ElMessage } from 'element-plus';
import { api } from '../api';
import { store } from '../store';

const exams = ref([]);
const students = ref([]);
const examId = ref(null);
const metric = ref('__total__');
const loading = ref(false);
const weights = reactive({});

const exam = computed(() => exams.value.find((e) => e.id === examId.value) || null);

async function load() {
  if (!store.currentClassId) return;
  loading.value = true;
  try {
    [exams.value, students.value] = await Promise.all([
      api.get(`/exams?classId=${store.currentClassId}`),
      api.get(`/students?classId=${store.currentClassId}`),
    ]);
    if (!exams.value.some((e) => e.id === examId.value)) {
      examId.value = exams.value.length ? exams.value[0].id : null;
    }
  } catch (e) {
    ElMessage.error(e.message);
  } finally {
    loading.value = false;
  }
}
watch(() => store.currentClassId, load, { immediate: true });

// 切换考试时重置指标与权重
watch(examId, () => {
  metric.value = '__total__';
  if (exam.value) exam.value.subjects.forEach((sub) => (weights[sub] = 1));
});

const hasValue = (v) => v !== null && v !== undefined && v !== '';

const ranked = computed(() => {
  const e = exam.value;
  if (!e) return [];
  const isTotal = metric.value === '__total__';
  const list = [];
  for (const [sid, sc] of Object.entries(e.scores || {})) {
    if (!sc || !Object.values(sc).some(hasValue)) continue;
    if (!isTotal && !hasValue(sc[metric.value])) continue;
    const stu = students.value.find((s) => s.id === sid);
    if (!stu) continue;
    const total = e.subjects.reduce(
      (sum, sub) => sum + (Number(sc[sub]) || 0) * (weights[sub] ?? 1),
      0
    );
    list.push({
      id: sid,
      name: stu.name,
      studentNo: stu.studentNo,
      sc,
      total: Math.round(total * 100) / 100,
      score: isTotal ? total : Number(sc[metric.value]) || 0,
    });
  }
  list.sort((a, b) => b.score - a.score);
  let rank = 0;
  let prev = null;
  list.forEach((r, i) => {
    if (r.score !== prev) {
      rank = i + 1;
      prev = r.score;
    }
    r.rank = rank;
  });
  return list;
});

function exportCsv() {
  const e = exam.value;
  if (!e || !ranked.value.length) return;
  const head = ['排名', '姓名', '学号', ...e.subjects, '加权总分'];
  const lines = [head.join(',')];
  for (const r of ranked.value) {
    lines.push(
      [r.rank, r.name, r.studentNo, ...e.subjects.map((s) => r.sc[s] ?? ''), r.total].join(',')
    );
  }
  const blob = new Blob(['\ufeff' + lines.join('\n')], { type: 'text/csv;charset=utf-8' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `${e.name}-成绩排名.csv`;
  a.click();
  URL.revokeObjectURL(a.href);
}
</script>
