<template>
  <div v-if="!store.currentClassId" class="empty-wrap">
    <el-empty description="请先在「班级管理」中创建并选择一个班级">
      <el-button type="primary" @click="$router.push('/classes')">去创建班级</el-button>
    </el-empty>
  </div>

  <div v-else class="card">
    <div class="toolbar">
      <el-button type="primary" @click="openAdd">＋ 新增学生</el-button>
      <el-button @click="importVisible = true">📥 导入 Excel/CSV</el-button>
      <el-button :disabled="!students.length" @click="exportXlsx">📤 导出名单</el-button>
      <el-button @click="downloadTemplate">📄 下载导入模板</el-button>
      <el-button type="danger" plain :disabled="!selection.length" @click="batchDelete">
        删除选中（{{ selection.length }}）
      </el-button>
      <span class="count">共 {{ students.length }} 名学生</span>
    </div>

    <el-table :data="students" stripe v-loading="loading" @selection-change="(s) => (selection = s)">
      <el-table-column type="selection" width="50" />
      <el-table-column prop="studentNo" label="学号" width="160">
        <template #default="{ row }">{{ row.studentNo || '-' }}</template>
      </el-table-column>
      <el-table-column prop="name" label="姓名" min-width="140" />
      <el-table-column label="性别" width="100">
        <template #default="{ row }">
          <el-tag v-if="row.gender" :type="row.gender === '女' ? 'danger' : 'primary'" effect="light">{{ row.gender }}</el-tag>
          <span v-else style="color: #c0c4cc">未填</span>
        </template>
      </el-table-column>
      <el-table-column label="操作" width="160">
        <template #default="{ row }">
          <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
          <el-button link type="danger" @click="removeOne(row)">删除</el-button>
        </template>
      </el-table-column>
      <template #empty>
        <el-empty description="暂无学生，可单个新增或从 Excel 批量导入" />
      </template>
    </el-table>

    <!-- 学生编辑 -->
    <el-dialog v-model="dialogVisible" :title="editing ? '编辑学生' : '新增学生'" width="440px">
      <el-form label-width="70px" @submit.prevent>
        <el-form-item label="姓名" required>
          <el-input v-model="form.name" placeholder="学生姓名" maxlength="20" @keyup.enter="submit" />
        </el-form-item>
        <el-form-item label="学号">
          <el-input v-model="form.studentNo" placeholder="选填" maxlength="30" />
        </el-form-item>
        <el-form-item label="性别">
          <el-radio-group v-model="form.gender">
            <el-radio value="男">男</el-radio>
            <el-radio value="女">女</el-radio>
            <el-radio value="">不填</el-radio>
          </el-radio-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="submit">保存</el-button>
      </template>
    </el-dialog>

    <!-- Excel 导入 -->
    <el-dialog v-model="importVisible" title="导入学生名单" width="640px" @closed="importRows = []">
      <el-alert type="info" :closable="false" show-icon style="margin-bottom: 14px"
        title="支持 .xlsx / .xls / .csv 文件，表头需包含「姓名」列，「学号」「性别」为选填列" />
      <el-upload
        drag
        accept=".xlsx,.xls,.csv"
        :auto-upload="false"
        :show-file-list="false"
        :on-change="onFileChange"
      >
        <div style="padding: 24px 0; color: #909399">
          将文件拖到此处，或 <span style="color: #409eff">点击选择文件</span>
        </div>
      </el-upload>

      <template v-if="importRows.length">
        <el-divider>解析结果（共 {{ importRows.length }} 条有效数据）</el-divider>
        <el-table :data="importRows" max-height="260" border size="small">
          <el-table-column prop="name" label="姓名" />
          <el-table-column prop="studentNo" label="学号">
            <template #default="{ row }">{{ row.studentNo || '-' }}</template>
          </el-table-column>
          <el-table-column prop="gender" label="性别">
            <template #default="{ row }">{{ row.gender || '-' }}</template>
          </el-table-column>
        </el-table>
        <div style="color: #909399; font-size: 13px; margin-top: 8px">
          与现有名单重复（姓名或学号相同）的学生将被自动跳过
        </div>
      </template>

      <template #footer>
        <el-button @click="importVisible = false">取消</el-button>
        <el-button type="primary" :disabled="!importRows.length" :loading="importing" @click="confirmImport">
          确认导入
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import * as XLSX from 'xlsx';
import { api } from '../api';
import { store } from '../store';

const students = ref([]);
const selection = ref([]);
const loading = ref(false);

const dialogVisible = ref(false);
const editing = ref(null);
const form = ref({ name: '', studentNo: '', gender: '' });
const saving = ref(false);

const importVisible = ref(false);
const importRows = ref([]);
const importing = ref(false);

async function load() {
  if (!store.currentClassId) {
    students.value = [];
    return;
  }
  loading.value = true;
  try {
    students.value = await api.get(`/students?classId=${store.currentClassId}`);
  } catch (e) {
    ElMessage.error(e.message);
  } finally {
    loading.value = false;
  }
}
watch(() => store.currentClassId, load, { immediate: true });

function openAdd() {
  editing.value = null;
  form.value = { name: '', studentNo: '', gender: '' };
  dialogVisible.value = true;
}

function openEdit(row) {
  editing.value = row;
  form.value = { name: row.name, studentNo: row.studentNo, gender: row.gender };
  dialogVisible.value = true;
}

async function submit() {
  if (!form.value.name.trim()) return ElMessage.warning('请输入学生姓名');
  saving.value = true;
  try {
    if (editing.value) await api.put(`/students/${editing.value.id}`, form.value);
    else await api.post('/students', { ...form.value, classId: store.currentClassId });
    dialogVisible.value = false;
    await load();
    await store.loadClasses();
    ElMessage.success('保存成功');
  } catch (e) {
    ElMessage.error(e.message);
  } finally {
    saving.value = false;
  }
}

async function removeOne(row) {
  try {
    await ElMessageBox.confirm(`确定删除学生「${row.name}」吗？其成绩与座位信息将一并清除。`, '删除学生', {
      type: 'warning',
    });
  } catch (_) {
    return;
  }
  try {
    await api.del(`/students/${row.id}`);
    await load();
    await store.loadClasses();
    ElMessage.success('删除成功');
  } catch (e) {
    ElMessage.error(e.message);
  }
}

async function batchDelete() {
  try {
    await ElMessageBox.confirm(`确定删除选中的 ${selection.value.length} 名学生吗？`, '批量删除', { type: 'warning' });
  } catch (_) {
    return;
  }
  try {
    for (const s of selection.value) await api.del(`/students/${s.id}`);
    ElMessage.success(`已删除 ${selection.value.length} 名学生`);
    await load();
    await store.loadClasses();
  } catch (e) {
    ElMessage.error(e.message);
    await load();
  }
}

/* ---------- Excel 导入 / 导出 ---------- */

function onFileChange(file) {
  const raw = file?.raw;
  if (!raw) return;
  const reader = new FileReader();
  reader.onload = (e) => {
    try {
      const wb = XLSX.read(new Uint8Array(e.target.result), { type: 'array' });
      const ws = wb.Sheets[wb.SheetNames[0]];
      if (!ws) throw new Error('文件中没有工作表');
      const rows = XLSX.utils.sheet_to_json(ws, { defval: '' });
      const mapped = rows
        .map((r) => {
          const get = (...keys) => {
            for (const k of keys) {
              const hit = Object.keys(r).find((kk) => String(kk).trim() === k);
              if (hit && String(r[hit]).trim()) return String(r[hit]).trim();
            }
            return '';
          };
          let gender = get('性别');
          if (/^(男|m|male)$/i.test(gender)) gender = '男';
          else if (/^(女|f|female)$/i.test(gender)) gender = '女';
          else gender = '';
          return { name: get('姓名', '名字'), studentNo: get('学号', '编号'), gender };
        })
        .filter((r) => r.name);
      if (!mapped.length) {
        ElMessage.warning('未解析到有效数据，请确认表头包含「姓名」列');
        return;
      }
      importRows.value = mapped;
    } catch (err) {
      ElMessage.error('文件解析失败：' + err.message);
    }
  };
  reader.readAsArrayBuffer(raw);
}

async function confirmImport() {
  importing.value = true;
  try {
    const res = await api.post('/students/import', {
      classId: store.currentClassId,
      students: importRows.value,
    });
    ElMessage.success(`导入完成：新增 ${res.added} 人，跳过 ${res.skipped} 人`);
    importVisible.value = false;
    importRows.value = [];
    await load();
    await store.loadClasses();
  } catch (e) {
    ElMessage.error(e.message);
  } finally {
    importing.value = false;
  }
}

function exportXlsx() {
  if (!students.value.length) return;
  const data = students.value.map((s) => ({ 学号: s.studentNo, 姓名: s.name, 性别: s.gender }));
  const ws = XLSX.utils.json_to_sheet(data);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, '学生名单');
  XLSX.writeFile(wb, `${store.currentClass?.name || '班级'}-学生名单.xlsx`);
}

function downloadTemplate() {
  const ws = XLSX.utils.json_to_sheet([
    { 学号: '2024001', 姓名: '张三', 性别: '男' },
    { 学号: '2024002', 姓名: '李四', 性别: '女' },
  ]);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, '名单');
  XLSX.writeFile(wb, '学生导入模板.xlsx');
}
</script>
