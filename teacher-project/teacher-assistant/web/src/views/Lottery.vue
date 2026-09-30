<template>
  <div v-if="!store.currentClassId" class="empty-wrap">
    <el-empty description="请先在「班级管理」中创建并选择一个班级">
      <el-button type="primary" @click="$router.push('/classes')">去创建班级</el-button>
    </el-empty>
  </div>

  <div v-else>
    <div class="card">
      <div class="toolbar">
        <span>抽取人数：</span>
        <el-input-number v-model="count" :min="1" :max="20" :disabled="rolling" />
        <el-checkbox v-model="excludeWon" :disabled="rolling">已抽中的不再参与</el-checkbox>
        <el-select
          v-model="manualExclude"
          multiple
          collapse-tags
          clearable
          filterable
          placeholder="手动排除（如请假学生）"
          style="width: 300px"
          :disabled="rolling"
        >
          <el-option v-for="s in students" :key="s.id" :label="s.name" :value="s.id" />
        </el-select>
        <el-button type="danger" size="large" round :loading="rolling" @click="draw">
          🎰 {{ rolling ? '抽奖中...' : '开始抽奖' }}
        </el-button>
        <span class="count">参与抽取：{{ poolSize }} 人</span>
      </div>
    </div>

    <div class="card" style="min-height: 260px">
      <div v-if="rolling" class="rolling-name">{{ rollingName }}</div>
      <template v-else-if="revealed.length">
        <div class="winners-title">🎉 恭喜以下 {{ revealed.length }} 位同学</div>
        <div class="winners">
          <div v-for="w in revealed" :key="w.id" class="winner-chip">{{ w.name }}</div>
        </div>
      </template>
      <div v-else class="stage-hint">点击「开始抽奖」随机抽取学生</div>
    </div>

    <div class="card">
      <div class="toolbar">
        <b>📋 抽奖历史</b>
        <el-button size="small" type="danger" plain :disabled="!records.length" @click="clearHistory">
          清空历史
        </el-button>
        <span class="count">{{ records.length }} 条记录</span>
      </div>
      <el-table :data="records" stripe max-height="380">
        <el-table-column label="时间" width="190">
          <template #default="{ row }">{{ new Date(row.ts).toLocaleString('zh-CN') }}</template>
        </el-table-column>
        <el-table-column label="抽取人数" width="100" prop="count" />
        <el-table-column label="中奖名单">
          <template #default="{ row }">{{ namesOf(row.winnerIds).join('、') || '-' }}</template>
        </el-table-column>
        <el-table-column label="操作" width="80">
          <template #default="{ row }">
            <el-button link type="danger" size="small" @click="removeRecord(row)">删除</el-button>
          </template>
        </el-table-column>
        <template #empty>
          <el-empty description="暂无抽奖记录" :image-size="80" />
        </template>
      </el-table>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onBeforeUnmount } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { api } from '../api';
import { store } from '../store';

const count = ref(1);
const excludeWon = ref(true);
const manualExclude = ref([]);
const students = ref([]);
const records = ref([]);
const rolling = ref(false);
const rollingName = ref('');
const revealed = ref([]);
let rollTimer = null;

async function load() {
  if (!store.currentClassId) return;
  try {
    [students.value, records.value] = await Promise.all([
      api.get(`/students?classId=${store.currentClassId}`),
      api.get(`/lottery?classId=${store.currentClassId}`),
    ]);
  } catch (e) {
    ElMessage.error(e.message);
  }
}
watch(() => store.currentClassId, load, { immediate: true });
onBeforeUnmount(() => clearInterval(rollTimer));

const poolSize = computed(() => {
  const exclude = new Set(manualExclude.value);
  if (excludeWon.value) records.value.forEach((r) => r.winnerIds.forEach((id) => exclude.add(id)));
  return students.value.filter((s) => !exclude.has(s.id)).length;
});

const namesOf = (ids) =>
  ids.map((id) => students.value.find((s) => s.id === id)?.name).filter(Boolean);

async function draw() {
  const exclude = new Set(manualExclude.value);
  if (excludeWon.value) records.value.forEach((r) => r.winnerIds.forEach((id) => exclude.add(id)));
  const pool = students.value.filter((s) => !exclude.has(s.id));
  if (!pool.length) return ElMessage.warning('没有可抽取的学生（都被排除了）');
  if (count.value > pool.length) {
    ElMessage.info(`可抽学生仅 ${pool.length} 人，将全部抽出`);
  }

  rolling.value = true;
  revealed.value = [];
  rollTimer = setInterval(() => {
    rollingName.value = pool[Math.floor(Math.random() * pool.length)].name;
  }, 70);

  try {
    const res = await api.post('/lottery/draw', {
      classId: store.currentClassId,
      count: count.value,
      excludeIds: [...exclude],
    });
    setTimeout(() => {
      clearInterval(rollTimer);
      rolling.value = false;
      res.winners.forEach((w, i) => setTimeout(() => revealed.value.push(w), i * 350));
      if (res.partial) ElMessage.info(`可抽人数不足，本轮抽出 ${res.winners.length} 人`);
      load();
    }, 2500);
  } catch (e) {
    clearInterval(rollTimer);
    rolling.value = false;
    ElMessage.error(e.message);
  }
}

async function clearHistory() {
  try {
    await ElMessageBox.confirm('确定清空该班级的全部抽奖记录吗？', '清空历史', { type: 'warning' });
  } catch (_) {
    return;
  }
  try {
    await api.del(`/lottery?classId=${store.currentClassId}`);
    ElMessage.success('已清空');
    load();
  } catch (e) {
    ElMessage.error(e.message);
  }
}

async function removeRecord(row) {
  try {
    await api.del(`/lottery/${row.id}`);
    load();
  } catch (e) {
    ElMessage.error(e.message);
  }
}
</script>
