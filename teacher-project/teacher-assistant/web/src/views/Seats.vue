<template>
  <div v-if="!store.currentClassId" class="empty-wrap">
    <el-empty description="请先在「班级管理」中创建并选择一个班级">
      <el-button type="primary" @click="$router.push('/classes')">去创建班级</el-button>
    </el-empty>
  </div>

  <div v-else>
    <div class="card">
      <div class="toolbar">
        <span>行数：</span>
        <el-input-number v-model="rows" :min="1" :max="20" size="small" @change="resize" />
        <span>列数：</span>
        <el-input-number v-model="cols" :min="1" :max="20" size="small" @change="resize" />

        <el-divider direction="vertical" />

        <el-button type="primary" @click="autoVisible = true">⚡ 自动编排</el-button>
        <el-button @click="clearSeats">清空座位</el-button>

        <el-divider direction="vertical" />

        <span style="color: #606266; font-size: 13px">交换模式</span>
        <el-switch v-model="swapMode" />
        <span style="color: #909399; font-size: 12px">{{ swapMode ? '依次点击两个座位完成交换' : '点击座位可分配学生 / 设为过道' }}</span>

        <span class="count">已就座 {{ seatedCount }} / {{ students.length }} 人</span>
      </div>

      <div class="seat-wrap" v-loading="loading">
        <div class="podium">讲 台</div>
        <div class="seat-grid" :style="{ gridTemplateColumns: `repeat(${cols}, minmax(96px, 1fr))` }">
          <div
            v-for="(cell, idx) in flatCells"
            :key="idx"
            class="seat"
            :class="seatClass(cell)"
            @click="onSeatClick(cell.r, cell.c)"
          >
            <span v-if="cell.blocked">过 道</span>
            <span v-else>{{ cell.name || '空 位' }}</span>
          </div>
        </div>
        <div class="seat-legend">
          <span>🔵 蓝色：已就座学生</span>
          <span>⚪ 灰色虚线：空位</span>
          <span>⚫ 深灰：过道</span>
        </div>
      </div>
    </div>

    <!-- 座位操作 -->
    <el-dialog v-model="seatDialog.visible" :title="`座位（第 ${seatDialog.r + 1} 行 · 第 ${seatDialog.c + 1} 列）`" width="440px">
      <div style="margin-bottom: 12px; color: #909399">
        当前：
        <b v-if="seatInfo.blocked" style="color: #909399">过道</b>
        <b v-else-if="seatInfo.studentName" style="color: #409eff">{{ seatInfo.studentName }}</b>
        <b v-else style="color: #c0c4cc">空位</b>
      </div>
      <el-select
        v-model="seatDialog.pickId"
        filterable
        placeholder="选择要安排到该座位的学生"
        style="width: 100%"
        :disabled="seatInfo.blocked"
      >
        <el-option v-for="s in unassigned" :key="s.id" :label="s.name" :value="s.id" />
      </el-select>
      <template #footer>
        <el-button v-if="seatInfo.blocked" @click="toggleBlocked">取消过道</el-button>
        <el-button v-else type="warning" plain @click="toggleBlocked">设为过道</el-button>
        <el-button :disabled="!seatInfo.studentId" @click="clearSeat">清空座位</el-button>
        <el-button type="primary" :disabled="!seatDialog.pickId" @click="assignSeat">分配</el-button>
      </template>
    </el-dialog>

    <!-- 自动编排 -->
    <el-dialog v-model="autoVisible" title="自动编排座位" width="480px">
      <el-form label-width="90px" @submit.prevent>
        <el-form-item label="编排方式">
          <el-radio-group v-model="autoMode">
            <el-radio value="random">随机打乱</el-radio>
            <el-radio value="snake">按成绩蛇形</el-radio>
          </el-radio-group>
        </el-form-item>
        <template v-if="autoMode === 'snake'">
          <el-form-item label="考试">
            <el-select v-model="autoExamId" placeholder="选择考试" style="width: 100%">
              <el-option v-for="e in exams" :key="e.id" :label="e.name" :value="e.id" />
            </el-select>
          </el-form-item>
          <el-form-item label="排序依据">
            <el-select v-model="autoMetric" placeholder="选择科目或总分" style="width: 100%">
              <el-option label="总分" value="__total__" />
              <el-option v-for="sub in autoExam?.subjects || []" :key="sub" :label="sub" :value="sub" />
            </el-select>
          </el-form-item>
        </template>
        <el-alert
          type="info"
          :closable="false"
          show-icon
          :title="autoMode === 'snake' ? '按所选成绩从高到低，以 S 形从前往后依次填充（过道自动跳过）' : '将全部学生随机打乱后从前往后填充（过道自动跳过）'"
        />
      </el-form>
      <template #footer>
        <el-button @click="autoVisible = false">取消</el-button>
        <el-button type="primary" @click="applyAutoArrange">开始编排</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, computed, watch, reactive } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { api } from '../api';
import { store } from '../store';

const students = ref([]);
const exams = ref([]);
const loading = ref(false);

const rows = ref(6);
const cols = ref(8);
const grid = ref([]);       // [[studentId | null]]
const blocked = ref([]);    // [[r, c]]

const swapMode = ref(false);
const swapFrom = ref(null); // {r, c}

const seatDialog = reactive({ visible: false, r: 0, c: 0, pickId: null });
const autoVisible = ref(false);
const autoMode = ref('random');
const autoExamId = ref(null);
const autoMetric = ref('__total__');

async function load() {
  if (!store.currentClassId) return;
  loading.value = true;
  try {
    [students.value, exams.value] = await Promise.all([
      api.get(`/students?classId=${store.currentClassId}`),
      api.get(`/exams?classId=${store.currentClassId}`),
    ]);
    const d = await api.get(`/seats/${store.currentClassId}`);
    rows.value = d.rows;
    cols.value = d.cols;
    blocked.value = d.blocked || [];
    grid.value = d.seats;
  } catch (e) {
    ElMessage.error(e.message);
  } finally {
    loading.value = false;
  }
}
watch(() => store.currentClassId, load, { immediate: true });

const isBlocked = (r, c) => blocked.value.some(([br, bc]) => br === r && bc === c);
const studentName = (id) => students.value.find((s) => s.id === id)?.name || '';

const flatCells = computed(() => {
  const out = [];
  for (let r = 0; r < rows.value; r++) {
    for (let c = 0; c < cols.value; c++) {
      const id = grid.value[r]?.[c] ?? null;
      out.push({ r, c, studentId: id, name: id ? studentName(id) : '', blocked: isBlocked(r, c) });
    }
  }
  return out;
});

const seatedCount = computed(() => flatCells.value.filter((x) => x.studentId).length);
const unassigned = computed(
  () => students.value.filter((s) => !flatCells.value.some((x) => x.studentId === s.id))
);

const autoExam = computed(() => exams.value.find((e) => e.id === autoExamId.value) || null);
watch(autoVisible, (v) => {
  if (v && exams.value.length && !autoExamId.value) autoExamId.value = exams.value[0].id;
});

function seatClass(cell) {
  if (cell.blocked) return 'blocked-seat';
  if (swapFrom.value && swapFrom.value.r === cell.r && swapFrom.value.c === cell.c) return 'selected-seat';
  return cell.studentId ? 'occupied' : 'empty-seat';
}

async function save() {
  try {
    await api.put(`/seats/${store.currentClassId}`, {
      rows: rows.value,
      cols: cols.value,
      blocked: blocked.value,
      seats: grid.value,
    });
  } catch (e) {
    ElMessage.error(e.message);
  }
}

function resize() {
  const ng = Array.from({ length: rows.value }, (_, r) =>
    Array.from({ length: cols.value }, (_, c) => grid.value[r]?.[c] ?? null)
  );
  grid.value = ng;
  blocked.value = blocked.value.filter(([r, c]) => r < rows.value && c < cols.value);
  save();
}

function onSeatClick(r, c) {
  if (loading.value) return;
  if (swapMode.value) {
    if (!swapFrom.value) {
      if (isBlocked(r, c)) return ElMessage.warning('过道不能交换');
      swapFrom.value = { r, c };
      return;
    }
    const a = swapFrom.value;
    const tmp = grid.value[a.r][a.c];
    grid.value[a.r][a.c] = grid.value[r][c];
    grid.value[r][c] = tmp;
    swapFrom.value = null;
    save();
    return;
  }
  seatDialog.visible = true;
  seatDialog.r = r;
  seatDialog.c = c;
  seatDialog.pickId = null;
}

// 对话框展示用的响应式信息（分配/交换/过道变更后自动更新）
const seatInfo = computed(() => {
  // 依赖 grid/blocked/seatDialog，保证交换或分配后信息更新
  void grid.value;
  void blocked.value;
  const id = grid.value[seatDialog.r]?.[seatDialog.c] ?? null;
  return {
    studentId: id,
    studentName: id ? studentName(id) : '',
    blocked: isBlocked(seatDialog.r, seatDialog.c),
  };
});

function assignSeat() {
  const { pickId } = seatDialog;
  if (!pickId) return;
  // 若该学生已在其他座位，先清掉原位置
  for (let r = 0; r < rows.value; r++) {
    for (let c = 0; c < cols.value; c++) {
      if (grid.value[r]?.[c] === pickId) grid.value[r][c] = null;
    }
  }
  grid.value[seatDialog.r][seatDialog.c] = pickId;
  seatDialog.visible = false;
  save();
  ElMessage.success(`已将 ${studentName(pickId)} 安排到该座位`);
}

function clearSeat() {
  grid.value[seatDialog.r][seatDialog.c] = null;
  seatDialog.visible = false;
  save();
}

function toggleBlocked() {
  const { r, c } = seatDialog;
  if (isBlocked(r, c)) {
    blocked.value = blocked.value.filter(([br, bc]) => !(br === r && bc === c));
  } else {
    blocked.value.push([r, c]);
    grid.value[r][c] = null;
  }
  seatDialog.visible = false;
  save();
}

async function clearSeats() {
  try {
    await ElMessageBox.confirm('确定清空全部座位安排吗？（过道设置保留）', '清空座位', { type: 'warning' });
  } catch (_) {
    return;
  }
  grid.value = Array.from({ length: rows.value }, () => Array(cols.value).fill(null));
  save();
  ElMessage.success('已清空');
}

function applyAutoArrange() {
  const seatsTotal = rows.value * cols.value - blocked.value.length;
  if (students.value.length > seatsTotal) {
    return ElMessage.warning(`学生 ${students.value.length} 人超过可用座位 ${seatsTotal} 个，请增加行/列数`);
  }

  let ordered = [...students.value];
  if (autoMode.value === 'snake') {
    const exam = autoExam.value;
    if (!exam) return ElMessage.warning('请选择考试');
    const metric = autoMetric.value;
    const scoreOf = (sid) => {
      const sc = exam.scores?.[sid] || {};
      if (metric === '__total__') {
        return exam.subjects.reduce((sum, sub) => sum + (Number(sc[sub]) || 0), 0);
      }
      return Number(sc[metric]) || 0;
    };
    ordered.sort((a, b) => scoreOf(b.id) - scoreOf(a.id));
  } else {
    for (let i = ordered.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [ordered[i], ordered[j]] = [ordered[j], ordered[i]];
    }
  }

  const g = Array.from({ length: rows.value }, () => Array(cols.value).fill(null));
  let i = 0;
  for (let r = 0; r < rows.value; r++) {
    // 蛇形：偶数行从左到右，奇数行从右到左
    const colOrder =
      r % 2 === 0
        ? Array.from({ length: cols.value }, (_, c) => c)
        : Array.from({ length: cols.value }, (_, c) => cols.value - 1 - c);
    for (const c of colOrder) {
      if (isBlocked(r, c)) continue;
      g[r][c] = ordered[i] ? ordered[i].id : null;
      i++;
    }
  }
  grid.value = g;
  autoVisible.value = false;
  save();
  ElMessage.success(autoMode.value === 'snake' ? '已按成绩蛇形编排完成' : '已随机编排完成');
}
</script>
