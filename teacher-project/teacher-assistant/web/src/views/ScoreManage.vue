<template>
  <div v-if="!store.currentClassId" class="empty-wrap">
    <el-empty description="请先在「班级管理」中创建并选择一个班级">
      <el-button type="primary" @click="$router.push('/classes')">去创建班级</el-button>
    </el-empty>
  </div>

  <div v-else class="card">
    <div class="toolbar">
      <span>考试：</span>
      <el-select v-model="examId" style="width: 260px" placeholder="选择考试">
        <el-option v-for="e in exams" :key="e.id" :label="e.name" :value="e.id" />
      </el-select>
      <el-button type="primary" @click="openCreate">＋ 新建考试</el-button>
      <el-button :disabled="!exam" @click="openEditExam">编辑考试</el-button>
      <el-button type="danger" plain :disabled="!exam" @click="removeExam">删除考试</el-button>
      <el-button type="success" :disabled="!exam" :loading="saving" @click="saveScores">💾 保存成绩</el-button>
      <span v-if="exam" class="count">{{ students.length }} 名学生 · {{ exam.subjects.length }} 个科目</span>
    </div>

    <template v-if="exam">
      <el-table :data="rows" stripe border max-height="580" v-loading="loading">
        <el-table-column prop="studentNo" label="学号" width="130" fixed>
          <template #default="{ row }">{{ row.studentNo || '-' }}</template>
        </el-table-column>
        <el-table-column prop="name" label="姓名" width="120" fixed />
        <el-table-column v-for="sub in exam.subjects" :key="sub" :label="sub" min-width="140" align="center">
          <template #header>
            <span>{{ sub }}</span>
          </template>
          <template #default="{ row }">
            <el-input-number
              v-model="row.scores[sub]"
              :min="0"
              :max="300"
              :step="1"
              :precision="1"
              controls-position="right"
              size="small"
              style="width: 120px"
              placeholder="未录入"
            />
          </template>
        </el-table-column>
      </el-table>
    </template>
    <el-empty v-else-if="!loading" description="还没有考试，点击「新建考试」创建一场考试并录入成绩" />
  </div>

  <!-- 新建/编辑考试 -->
  <el-dialog v-model="dialogVisible" :title="editingExam ? '编辑考试' : '新建考试'" width="480px">
    <el-form label-width="80px" @submit.prevent>
      <el-form-item label="考试名称" required>
        <el-input v-model="examForm.name" placeholder="如：期中考试" maxlength="30" />
      </el-form-item>
      <el-form-item label="考试日期">
        <el-date-picker v-model="examForm.date" type="date" value-format="YYYY-MM-DD" placeholder="选择日期" style="width: 100%" />
      </el-form-item>
      <el-form-item label="考试科目" required>
        <div style="display: flex; gap: 8px; width: 100%">
          <el-input
            v-model="subjectInput"
            placeholder="输入科目名后回车，如：语文"
            maxlength="10"
            @keyup.enter.prevent="addSubject"
          />
          <el-button @click="addSubject">添加</el-button>
        </div>
        <div style="margin-top: 8px; display: flex; gap: 6px; flex-wrap: wrap">
          <el-tag
            v-for="sub in examForm.subjects"
            :key="sub"
            closable
            @close="examForm.subjects = examForm.subjects.filter((x) => x !== sub)"
          >
            {{ sub }}
          </el-tag>
          <span v-if="!examForm.subjects.length" style="color: #c0c4cc; font-size: 13px">至少添加一个科目</span>
        </div>
        <div v-if="editingExam" style="color: #e6a23c; font-size: 12px; margin-top: 6px">
          注意：删除科目会同时丢弃该科目的已录入成绩
        </div>
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="dialogVisible = false">取消</el-button>
      <el-button type="primary" :loading="savingExam" @click="submitExam">保存</el-button>
    </template>
  </el-dialog>
</template>

<script setup>
import { ref, computed, watch } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { api } from '../api';
import { store } from '../store';

const students = ref([]);
const exams = ref([]);
const examId = ref(null);
const loading = ref(false);

const localScores = ref({}); // { studentId: { subject: number|null } }
const saving = ref(false);

const dialogVisible = ref(false);
const editingExam = ref(null);
const examForm = ref({ name: '', date: '', subjects: [] });
const subjectInput = ref('');
const savingExam = ref(false);

const exam = computed(() => exams.value.find((e) => e.id === examId.value) || null);

// 表格行：指向 localScores 中的对象，保证编辑不丢失
const rows = computed(() =>
  students.value.map((s) => ({ ...s, scores: localScores.value[s.id] || {} }))
);

async function load() {
  if (!store.currentClassId) return;
  loading.value = true;
  try {
    [students.value, exams.value] = await Promise.all([
      api.get(`/students?classId=${store.currentClassId}`),
      api.get(`/exams?classId=${store.currentClassId}`),
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

// 切换考试时，把成绩拷贝到本地编辑副本
watch([examId, () => students.value.length, () => exams.value.length], buildLocal);
function buildLocal() {
  if (!exam.value) {
    localScores.value = {};
    return;
  }
  const next = {};
  for (const s of students.value) {
    next[s.id] = {};
    for (const sub of exam.value.subjects) {
      const v = exam.value.scores?.[s.id]?.[sub];
      next[s.id][sub] = v == null || v === '' ? null : Number(v);
    }
  }
  localScores.value = next;
}

function openCreate() {
  editingExam.value = null;
  examForm.value = { name: '', date: '', subjects: [] };
  dialogVisible.value = true;
}

function openEditExam() {
  if (!exam.value) return;
  editingExam.value = exam.value;
  examForm.value = { name: exam.value.name, date: exam.value.date, subjects: [...exam.value.subjects] };
  dialogVisible.value = true;
}

function addSubject() {
  const v = subjectInput.value.trim();
  if (!v) return;
  if (!examForm.value.subjects.includes(v)) examForm.value.subjects.push(v);
  subjectInput.value = '';
}

async function submitExam() {
  if (!examForm.value.name.trim()) return ElMessage.warning('请输入考试名称');
  if (!examForm.value.subjects.length) return ElMessage.warning('请至少添加一个科目');
  savingExam.value = true;
  try {
    if (editingExam.value) {
      await api.put(`/exams/${editingExam.value.id}`, examForm.value);
    } else {
      const created = await api.post('/exams', { ...examForm.value, classId: store.currentClassId });
      examId.value = created.id;
    }
    dialogVisible.value = false;
    await load();
    buildLocal();
    ElMessage.success('保存成功');
  } catch (e) {
    ElMessage.error(e.message);
  } finally {
    savingExam.value = false;
  }
}

async function removeExam() {
  if (!exam.value) return;
  try {
    await ElMessageBox.confirm(`确定删除考试「${exam.value.name}」及其全部成绩吗？`, '删除考试', { type: 'warning' });
  } catch (_) {
    return;
  }
  try {
    await api.del(`/exams/${exam.value.id}`);
    examId.value = null;
    await load();
    ElMessage.success('删除成功');
  } catch (e) {
    ElMessage.error(e.message);
  }
}

async function saveScores() {
  if (!exam.value) return;
  saving.value = true;
  try {
    await api.put(`/exams/${exam.value.id}`, { scores: localScores.value });
    await load();
    buildLocal();
    ElMessage.success('成绩已保存');
  } catch (e) {
    ElMessage.error(e.message);
  } finally {
    saving.value = false;
  }
}
</script>
