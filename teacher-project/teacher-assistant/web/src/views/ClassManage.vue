<template>
  <div class="card">
    <div class="toolbar">
      <el-button type="primary" @click="openAdd">＋ 新建班级</el-button>
      <span class="count">共 {{ classes.length }} 个班级</span>
    </div>

    <el-table :data="classes" stripe v-loading="loading">
      <el-table-column prop="name" label="班级名称" min-width="200" />
      <el-table-column prop="studentCount" label="学生人数" width="120" sortable />
      <el-table-column label="创建时间" width="220">
        <template #default="{ row }">{{ formatTime(row.createdAt) }}</template>
      </el-table-column>
      <el-table-column label="操作" width="200">
        <template #default="{ row }">
          <el-button link type="primary" @click="openEdit(row)">重命名</el-button>
          <el-button link type="danger" @click="removeClass(row)">删除</el-button>
        </template>
      </el-table-column>
      <template #empty>
        <el-empty description="还没有班级，点击上方按钮创建第一个班级" />
      </template>
    </el-table>

    <el-dialog v-model="dialogVisible" :title="editing ? '重命名班级' : '新建班级'" width="420px">
      <el-form label-width="80px" @submit.prevent>
        <el-form-item label="班级名称" required>
          <el-input v-model="form.name" placeholder="如：三年二班" maxlength="30" @keyup.enter="submit" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="submit">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { api } from '../api';
import { store } from '../store';

const classes = computed(() => store.classes);
const loading = ref(false);
const dialogVisible = ref(false);
const editing = ref(null);
const form = ref({ name: '' });
const saving = ref(false);

const formatTime = (t) => (t ? new Date(t).toLocaleString('zh-CN') : '-');

function openAdd() {
  editing.value = null;
  form.value = { name: '' };
  dialogVisible.value = true;
}

function openEdit(row) {
  editing.value = row;
  form.value = { name: row.name };
  dialogVisible.value = true;
}

async function submit() {
  if (!form.value.name.trim()) return ElMessage.warning('请输入班级名称');
  saving.value = true;
  try {
    if (editing.value) await api.put(`/classes/${editing.value.id}`, form.value);
    else await api.post('/classes', form.value);
    dialogVisible.value = false;
    await store.loadClasses();
    ElMessage.success('保存成功');
  } catch (e) {
    ElMessage.error(e.message);
  } finally {
    saving.value = false;
  }
}

async function removeClass(row) {
  try {
    await ElMessageBox.confirm(
      `删除班级「${row.name}」将同时删除该班的 ${row.studentCount} 名学生、全部成绩、抽奖记录和座位表，且不可恢复。确定删除吗？`,
      '删除班级',
      { type: 'warning', confirmButtonText: '确定删除', cancelButtonText: '取消' }
    );
  } catch (_) {
    return;
  }
  try {
    await api.del(`/classes/${row.id}`);
    await store.loadClasses();
    ElMessage.success('删除成功');
  } catch (e) {
    ElMessage.error(e.message);
  }
}
</script>
