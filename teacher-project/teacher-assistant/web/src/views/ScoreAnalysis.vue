<template>
  <div v-if="!store.currentClassId" class="empty-wrap">
    <el-empty description="请先在「班级管理」中创建并选择一个班级">
      <el-button type="primary" @click="$router.push('/classes')">去创建班级</el-button>
    </el-empty>
  </div>

  <div v-else>
    <!-- 选择考试 -->
    <div class="card">
      <div class="toolbar">
        <span class="lbl">分析考试：</span>
        <el-select v-model="examId" style="width: 220px" placeholder="选择考试" @change="onExamChange">
          <el-option v-for="e in exams" :key="e.id" :label="e.name + (e.date ? `（${e.date}）` : '')" :value="e.id" />
        </el-select>
        <span class="lbl">满分：</span>
        <el-input-number v-model="fullScore" :min="20" :max="200" :step="10" style="width: 110px" @change="render" />
        <span class="lbl">对比考试：</span>
        <el-select v-model="compareId" clearable placeholder="选择对比考试（选填）" style="width: 220px" @change="render">
          <el-option v-for="e in comparableExams" :key="e.id" :label="e.name + (e.date ? `（${e.date}）` : '')" :value="e.id" />
        </el-select>
        <el-button v-if="examId" type="primary" :loading="aiLoading" @click="runAI">🤖 AI 智能分析</el-button>
      </div>
      <div v-if="aiHint" class="muted" style="font-size: 12px">💡 AI 分析会把班级统计数据发送给大模型服务（{{ aiModel }}），请确认无保密要求</div>
    </div>

    <template v-if="exam">
      <!-- 各科统计 -->
      <div class="card">
        <h3 class="sec-title">各科统计</h3>
        <el-table :data="subjectStats" border size="small">
          <el-table-column prop="subject" label="科目" width="100" fixed />
          <el-table-column prop="count" label="参考人数" width="90" align="center" />
          <el-table-column prop="avg" label="平均分" width="85" align="center" />
          <el-table-column prop="max" label="最高分" width="85" align="center">
            <template #default="{ row }"><span class="good">{{ row.max }}</span></template>
          </el-table-column>
          <el-table-column prop="min" label="最低分" width="85" align="center">
            <template #default="{ row }"><span class="bad">{{ row.min }}</span></template>
          </el-table-column>
          <el-table-column prop="median" label="中位数" width="85" align="center" />
          <el-table-column prop="std" label="标准差" width="85" align="center" />
          <el-table-column prop="passRate" label="及格率" width="90" align="center">
            <template #default="{ row }">
              <el-tag :type="rateType(row.passNum, row.count)" size="small">{{ row.passRate }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="excellentRate" label="优秀率" width="90" align="center">
            <template #default="{ row }">
              <el-tag :type="rateType(row.excellentNum, row.count)" size="small" effect="light">{{ row.excellentRate }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column label="分数段分布">
            <template #default="{ row }">
              <div class="mini-bars">
                <div v-for="(seg, i) in row.segments" :key="i" class="mini-bar" :title="seg.label + '：' + seg.count + ' 人'">
                  <div class="mini-bar-fill" :style="{ height: barH(seg.count, row.count), background: segColors[i] }"></div>
                  <span class="mini-bar-num">{{ seg.count || '' }}</span>
                </div>
              </div>
            </template>
          </el-table-column>
        </el-table>
        <div class="muted" style="margin-top: 8px; font-size: 12px">
          及格线 = 满分 × 60%，优秀线 = 满分 × 85%（当前满分 {{ fullScore }}，修改满分后统计自动重算）
        </div>
      </div>

      <!-- 总分分布 -->
      <div class="card" v-if="totalSegments.length">
        <h3 class="sec-title">总分分数段分布（按满分 {{ fullScore * (exam.subjects.length || 1) }} 折算）</h3>
        <div class="dist-chart">
          <div v-for="(seg, i) in totalSegments" :key="i" class="dist-col">
            <span class="dist-num">{{ seg.count }}</span>
            <div class="dist-bar" :style="{ height: distH(seg.count), background: segColors[i] }"></div>
            <span class="dist-label">{{ seg.label }}</span>
          </div>
        </div>
      </div>

      <!-- 两考试对比 -->
      <div class="card" v-if="compareData">
        <h3 class="sec-title">对比分析：{{ compareData.otherName }} → {{ exam.name }}</h3>
        <div class="cmp-grid">
          <div class="cmp-box">
            <div class="cmp-title">📈 进步榜 Top 5</div>
            <div v-for="r in compareData.risers" :key="r.id" class="cmp-row">
              <span>{{ r.name }}</span>
              <span class="good">{{ r.delta > 0 ? '+' : '' }}{{ r.delta }}</span>
            </div>
            <div v-if="!compareData.risers.length" class="muted">无进步学生</div>
          </div>
          <div class="cmp-box">
            <div class="cmp-title">📉 退步榜 Top 5</div>
            <div v-for="r in compareData.fallers" :key="r.id" class="cmp-row">
              <span>{{ r.name }}</span>
              <span class="bad">{{ r.delta > 0 ? '+' : '' }}{{ r.delta }}</span>
            </div>
            <div v-if="!compareData.fallers.length" class="muted">无退步学生</div>
          </div>
          <div class="cmp-box">
            <div class="cmp-title">📊 整体变化</div>
            <div class="cmp-row"><span>平均总分</span><span :class="compareData.avgDelta >= 0 ? 'good' : 'bad'">{{ compareData.avgDelta >= 0 ? '+' : '' }}{{ compareData.avgDelta }}</span></div>
            <div class="cmp-row"><span>参加对比人数</span><span>{{ compareData.count }} 人</span></div>
            <div class="cmp-row"><span>进步人数</span><span class="good">{{ compareData.riseCount }} 人</span></div>
            <div class="cmp-row"><span>退步人数</span><span class="bad">{{ compareData.fallCount }} 人</span></div>
          </div>
        </div>
      </div>

      <!-- AI 分析结果 -->
      <div class="card" v-if="aiContent || aiLoading || aiError">
        <h3 class="sec-title">🤖 AI 教学分析报告</h3>
        <div class="ai-input-row" style="margin-bottom: 12px">
          <el-input
            v-model="aiQuestion"
            placeholder="想重点了解什么？（选填，如：数学低分段学生如何辅导？）"
            clearable
            :disabled="aiLoading"
            @keyup.enter="runAI"
          />
          <el-button type="primary" :loading="aiLoading" @click="runAI">重新分析</el-button>
        </div>
        <div v-if="aiLoading" v-loading="true" style="height: 160px" element-loading-text="大模型分析中，约需 10-30 秒（限流时会自动重试，请稍候）…"></div>
        <el-alert
          v-else-if="aiError"
          type="error"
          :closable="false"
          show-icon
        >
          <template #title>AI 分析失败</template>
          <div style="line-height: 1.7">{{ aiError }}</div>
          <div style="margin-top: 10px">
            <el-button type="primary" size="small" @click="runAI">稍后重试</el-button>
          </div>
        </el-alert>
        <div v-else class="md-view" v-html="aiHtml"></div>
      </div>

      <div class="card empty-wrap" v-if="!exams.length">
        <el-empty description="该班级还没有考试数据，请先在「成绩管理」中创建考试并录入成绩">
          <el-button type="primary" @click="$router.push('/scores')">去录成绩</el-button>
        </el-empty>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue';
import { ElMessage } from 'element-plus';
import { api } from '../api';
import { store } from '../store';

const exams = ref([]);
const examId = ref(null);
const compareId = ref(null);
const fullScore = ref(100);
const segColors = ['#f56c6c', '#e6a23c', '#fadb14', '#95d475', '#67c23a', '#409eff'];

const aiStatus = ref({ configured: false, model: null });
const aiModel = computed(() => aiStatus.value.model || 'agnes-2.0-flash');
const aiHint = computed(() => aiStatus.value.configured);
const aiLoading = ref(false);
const aiContent = ref('');
const aiError = ref('');
const aiQuestion = ref('');

async function load() {
  aiContent.value = '';
  if (!store.currentClassId) {
    exams.value = [];
    return;
  }
  try {
    const list = await api.get(`/exams?classId=${store.currentClassId}`);
    exams.value = [...list].sort((a, b) => (b.date || '').localeCompare(a.date || ''));
    if (!exams.value.some((e) => e.id === examId.value)) examId.value = exams.value[0]?.id || null;
    if (compareId.value && !exams.value.some((e) => e.id === compareId.value)) compareId.value = null;
    api.get('/ai/status').then((s) => (aiStatus.value = s)).catch(() => {});
  } catch (e) {
    ElMessage.error(e.message);
  }
}
watch(() => store.currentClassId, load, { immediate: true });

const exam = computed(() => exams.value.find((e) => e.id === examId.value) || null);
const comparableExams = computed(() => exams.value.filter((e) => e.id !== examId.value));

function onExamChange() {
  aiContent.value = '';
}

/* ---------- 统计计算 ---------- */

const hasVal = (v) => v !== undefined && v !== null && v !== '' && !isNaN(Number(v));

function calcStats(values, full) {
  const nums = values.map(Number).sort((a, b) => a - b);
  if (!nums.length) return null;
  const sum = nums.reduce((a, b) => a + b, 0);
  const avg = sum / nums.length;
  const mid = Math.floor(nums.length / 2);
  const median = nums.length % 2 ? nums[mid] : (nums[mid - 1] + nums[mid]) / 2;
  const std = Math.sqrt(nums.reduce((s, n) => s + (n - avg) ** 2, 0) / nums.length);
  const passLine = full * 0.6;
  const exLine = full * 0.85;
  const passNum = nums.filter((n) => n >= passLine).length;
  const excellentNum = nums.filter((n) => n >= exLine).length;
  const pct = (n) => Math.round((n / nums.length) * 100) + '%';
  return {
    count: nums.length,
    avg: Math.round(avg * 10) / 10,
    max: nums[nums.length - 1],
    min: nums[0],
    median,
    std: Math.round(std * 10) / 10,
    passNum,
    excellentNum,
    passRate: pct(passNum),
    excellentRate: pct(excellentNum),
  };
}

function segments(values, full) {
  // 按满分 5 等分（不足 60%/60-70/70-80/80-90/90+，满分制）
  const labels = ['0-59%', '60-70%', '70-80%', '80-90%', '90-100%'];
  const nums = values.map(Number);
  return labels.map((label, i) => {
    const lo = full * (0.5 + i * 0.1);
    const hi = full * (0.6 + i * 0.1);
    const count = nums.filter((n) => (i === 0 ? n < hi : i === labels.length - 1 ? n >= lo : n >= lo && n < hi)).length;
    return { label, count };
  });
}

const subjectStats = computed(() => {
  const e = exam.value;
  if (!e) return [];
  return (e.subjects || []).map((sub) => {
    const values = Object.values(e.scores || {})
      .filter((sc) => sc && hasVal(sc[sub]))
      .map((sc) => Number(sc[sub]));
    const st = calcStats(values, fullScore.value) || {};
    return { subject: sub, ...st, segments: segments(values, fullScore.value) };
  });
});

const totalSegments = computed(() => {
  const e = exam.value;
  if (!e || !e.subjects?.length) return [];
  const values = Object.values(e.scores || {})
    .filter((sc) => sc && (e.subjects || []).some((sub) => hasVal(sc[sub])))
    .map((sc) => (e.subjects || []).reduce((s, sub) => s + (hasVal(sc[sub]) ? Number(sc[sub]) : 0), 0));
  return segments(values, fullScore.value * e.subjects.length);
});

function rateType(num, count) {
  if (!count) return 'info';
  const r = num / count;
  return r >= 0.8 ? 'success' : r >= 0.5 ? 'warning' : 'danger';
}

function barH(count, total) {
  return Math.max(2, Math.round((count / (total || 1)) * 46)) + 'px';
}
function distH(count) {
  const max = Math.max(...totalSegments.value.map((s) => s.count), 1);
  return Math.max(4, Math.round((count / max) * 140)) + 'px';
}

/* ---------- 两考试对比 ---------- */

const compareData = computed(() => {
  const e = exam.value;
  const o = exams.value.find((x) => x.id === compareId.value);
  if (!e || !o) return null;
  const rows = [];
  for (const [sid, sc] of Object.entries(e.scores || {})) {
    const prev = o.scores?.[sid];
    if (!sc || !prev) continue;
    const total = (arr, s) => (arr.subjects || []).reduce((sum, sub) => sum + (hasVal(s[sub]) ? Number(s[sub]) : 0), 0);
    const delta = Math.round(((total(e, sc) - total(o, prev)) * 100)) / 100;
    const stu = students.value.find((s) => s.id === sid);
    rows.push({ id: sid, name: stu?.name || '未知', delta });
  }
  if (!rows.length) return null;
  const sorted = [...rows].sort((a, b) => b.delta - a.delta);
  const avgDelta = Math.round((rows.reduce((s, r) => s + r.delta, 0) / rows.length) * 10) / 10;
  return {
    otherName: o.name,
    risers: sorted.slice(0, 5).filter((r) => r.delta > 0),
    fallers: [...sorted].reverse().slice(0, 5).filter((r) => r.delta < 0),
    avgDelta,
    count: rows.length,
    riseCount: rows.filter((r) => r.delta > 0).length,
    fallCount: rows.filter((r) => r.delta < 0).length,
  };
});

/* students 数据（对比榜需要姓名） */
const students = ref([]);
watch(
  () => store.currentClassId,
  async () => {
    if (!store.currentClassId) {
      students.value = [];
      return;
    }
    try {
      students.value = await api.get(`/students?classId=${store.currentClassId}`);
    } catch (_) { /* 忽略 */ }
  },
  { immediate: true }
);

function render() { /* 依赖 computed 自动重算，占位触发 */ }

/* ---------- AI 分析 ---------- */

async function runAI() {
  const e = exam.value;
  if (!e) return;
  if (!aiStatus.value.configured) return ElMessage.warning('AI 未配置');
  aiLoading.value = true;
  aiContent.value = '';
  aiError.value = '';
  try {
    // 组装统计数据
    const subjectDetail = subjectStats.value.map((s) => ({
      subject: s.subject,
      参考人数: s.count,
      平均分: s.avg,
      最高分: s.max,
      最低分: s.min,
      中位数: s.median,
      标准差: s.std,
      及格率: s.passRate,
      优秀率: s.excellentRate,
      分数段人数: s.segments.map((x) => x.label + ':' + x.count).join(', '),
    }));
    const totals = Object.entries(e.scores || {})
      .filter(([, sc]) => sc && (e.subjects || []).some((sub) => hasVal(sc[sub])))
      .map(([sid, sc]) => ({
        学生: students.value.find((s) => s.id === sid)?.name || '未知',
        总分: (e.subjects || []).reduce((sum, sub) => sum + (hasVal(sc[sub]) ? Number(sc[sub]) : 0), 0),
      }))
      .sort((a, b) => b.总分 - a.总分);
    const stats = {
      班级: store.currentClass?.name,
      考试: e.name,
      满分标准: fullScore.value,
      班级人数: students.value.length,
      各科统计: subjectDetail,
      总分排名: totals.map((t, i) => ({ 名次: i + 1, 姓名: t.学生, 总分: t.总分 })),
    };
    if (compareData.value) {
      stats.对比分析 = {
        对比考试: compareData.value.otherName,
        平均总分变化: compareData.value.avgDelta,
        进步人数: compareData.value.riseCount,
        退步人数: compareData.value.fallCount,
        进步榜: compareData.value.risers,
        退步榜: compareData.value.fallers,
      };
    }
    const res = await api.post('/ai/analyze', {
      classId: store.currentClassId,
      examId: e.id,
      stats,
      question: aiQuestion.value || '',
    });
    aiContent.value = res.content;
  } catch (err) {
    aiError.value = err.message;
  } finally {
    aiLoading.value = false;
  }
}

/* ---------- 简易 Markdown 渲染 ---------- */

const aiHtml = computed(() => {
  const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  if (!aiContent.value) return '';
  const lines = esc(aiContent.value).split(/\r?\n/);
  const out = [];
  let inList = false;
  let tableRows = [];
  const closeList = () => {
    if (inList) {
      out.push('</ul>');
      inList = false;
    }
  };
  const flushTable = () => {
    if (!tableRows.length) return;
    const rows = tableRows.filter((r) => !/^\|[\s:|-]+\|$/.test(r));
    const cells = rows.map((r) =>
      r.replace(/^\||\|$/g, '').split('|').map((c) => c.trim())
    );
    let html = '<table class="md-table"><thead><tr>';
    for (const c of cells[0] || []) html += `<th>${c}</th>`;
    html += '</tr></thead><tbody>';
    for (const row of cells.slice(1)) {
      html += '<tr>';
      for (const c of row) html += `<td>${c}</td>`;
      html += '</tr>';
    }
    html += '</tbody></table>';
    out.push(html);
    tableRows = [];
  };
  for (let line of lines) {
    line = line.trimEnd();
    if (/^\|.*\|$/.test(line)) {
      closeList();
      tableRows.push(line);
      continue;
    }
    flushTable();
    if (/^#{1,6}\s+/.test(line)) {
      closeList();
      out.push(`<h3>${line.replace(/^#{1,6}\s+/, '')}</h3>`);
    } else if (/^[-*•]\s+/.test(line)) {
      if (!inList) {
        out.push('<ul>');
        inList = true;
      }
      out.push(`<li>${line.replace(/^[-*•]\s+/, '')}</li>`);
    } else if (/^\d+[.、)]\s+/.test(line)) {
      if (!inList) {
        out.push('<ul>');
        inList = true;
      }
      out.push(`<li>${line.replace(/^\d+[.、)]\s+/, '')}</li>`);
    } else if (line.trim() === '') {
      closeList();
    } else {
      closeList();
      out.push(`<p>${line}</p>`);
    }
  }
  closeList();
  flushTable();
  return out
    .join('\n')
    .replace(/\*\*([^*]+)\*\*/g, '<b>$1</b>')
    .replace(/(?<!\*)\*([^*\n]+)\*(?!\*)/g, '<i>$1</i>');
});
</script>

<style scoped>
.lbl { color: #606266; font-size: 14px; }
.sec-title { margin: 0 0 14px; font-size: 16px; color: #303133; }
.muted { color: #909399; }
.good { color: #67c23a; font-weight: 600; }
.bad { color: #f56c6c; font-weight: 600; }

.mini-bars { display: flex; gap: 6px; align-items: flex-end; height: 52px; }
.mini-bar { display: flex; flex-direction: column; align-items: center; justify-content: flex-end; width: 26px; }
.mini-bar-fill { width: 100%; border-radius: 3px 3px 0 0; min-height: 2px; }
.mini-bar-num { font-size: 10px; color: #909399; line-height: 1.2; }

.dist-chart { display: flex; gap: 28px; align-items: flex-end; justify-content: center; padding: 10px 0 4px; min-height: 210px; }
.dist-col { display: flex; flex-direction: column; align-items: center; justify-content: flex-end; }
.dist-num { font-size: 13px; color: #606266; margin-bottom: 4px; }
.dist-bar { width: 56px; border-radius: 6px 6px 0 0; min-height: 4px; transition: height 0.4s ease; }
.dist-label { font-size: 12px; color: #909399; margin-top: 6px; white-space: nowrap; }

.cmp-grid { display: flex; gap: 14px; flex-wrap: wrap; }
.cmp-box { flex: 1; min-width: 240px; background: #f5f7fa; border-radius: 8px; padding: 14px; }
.cmp-title { font-weight: 600; margin-bottom: 10px; color: #303133; }
.cmp-row { display: flex; justify-content: space-between; padding: 4px 0; font-size: 14px; color: #606266; }

.ai-input-row { display: flex; gap: 10px; }

:deep(.md-table) { border-collapse: collapse; margin: 10px 0; font-size: 13px; }
:deep(.md-table th), :deep(.md-table td) { border: 1px solid #dcdfe6; padding: 6px 14px; }
:deep(.md-table th) { background: #f5f7fa; }
</style>
