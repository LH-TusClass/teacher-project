require('dotenv').config();
const express = require('express');
const crypto = require('crypto');
const db = require('./db');
const cache = require('./cache');

const app = express();
const PORT = process.env.PORT || 3210;

app.use(express.json({ limit: '10mb' }));

/* 前后端分离：允许跨域访问 API */
const corsOrigin = process.env.CORS_ORIGIN || '*';
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', corsOrigin);
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

const bad = (res, msg) => res.status(400).json({ error: msg });
const notFound = (res, msg) => res.status(404).json({ error: msg });
const fail = (res, err) => {
  console.error('[error]', err && err.message ? err.message : err);
  res.status(500).json({ error: '服务器内部错误' });
};
const wrap = (fn) => (req, res) => Promise.resolve(fn(req, res)).catch((err) => fail(res, err));
// mysql2 会把 MySQL JSON 列解析为 JS 对象，与旧版字符串兜底兼容
const parseJson = (v, fallback) => {
  if (v === null || v === undefined) return fallback;
  if (typeof v === 'string') {
    try { return JSON.parse(v); } catch (_) { return fallback; }
  }
  return v;
};

/* ==================== 班级 ==================== */

app.get('/api/classes', wrap(async (req, res) => {
  const data = await cache.cachedRead('classes', async () => {
    const rows = await db.query('SELECT id, name, created_at AS createdAt FROM classes ORDER BY created_at ASC');
    const counts = await db.query('SELECT class_id, COUNT(*) AS c FROM students GROUP BY class_id');
    const map = {};
    for (const row of counts) map[row.class_id] = row.c;
    return rows.map((r) => ({ ...r, studentCount: map[r.id] || 0 }));
  });
  res.json(data);
}));

app.post('/api/classes', wrap(async (req, res) => {
  const name = String(req.body.name || '').trim();
  if (!name) return bad(res, '班级名称不能为空');
  const dup = await db.query('SELECT id FROM classes WHERE name = ?', [name]);
  if (dup.length) return bad(res, '班级名称已存在');
  const cls = { id: db.uid('cls'), name, createdAt: new Date() };
  await db.execute('INSERT INTO classes (id, name, created_at) VALUES (?, ?, ?)', [cls.id, cls.name, cls.createdAt]);
  await cache.invalidate();
  res.status(201).json(cls);
}));

app.put('/api/classes/:id', wrap(async (req, res) => {
  const name = String(req.body.name || '').trim();
  if (!name) return bad(res, '班级名称不能为空');
  const exists = await db.query('SELECT id FROM classes WHERE id = ?', [req.params.id]);
  if (!exists.length) return notFound(res, '班级不存在');
  const dup = await db.query('SELECT id FROM classes WHERE name = ? AND id <> ?', [name, req.params.id]);
  if (dup.length) return bad(res, '班级名称已存在');
  await db.execute('UPDATE classes SET name = ? WHERE id = ?', [name, req.params.id]);
  await cache.invalidate();
  const updated = await db.query('SELECT id, name, created_at AS createdAt FROM classes WHERE id = ?', [req.params.id]);
  res.json(updated[0]);
}));

app.delete('/api/classes/:id', wrap(async (req, res) => {
  const { id } = req.params;
  const exists = await db.query('SELECT id FROM classes WHERE id = ?', [id]);
  if (!exists.length) return notFound(res, '班级不存在');
  // 学生、考试、成绩、抽奖记录、座位表均通过外键 ON DELETE CASCADE 级联清理
  await db.execute('DELETE FROM classes WHERE id = ?', [id]);
  await cache.invalidate();
  res.json({ ok: true });
}));

/* ==================== 学生 ==================== */

app.get('/api/students', wrap(async (req, res) => {
  const { classId } = req.query;
  const data = await cache.cachedRead(`students:${classId || 'all'}`, async () => {
    const sql = classId
      ? 'SELECT id, class_id AS classId, name, student_no AS studentNo, gender FROM students WHERE class_id = ? ORDER BY created_at ASC, id ASC'
      : 'SELECT id, class_id AS classId, name, student_no AS studentNo, gender FROM students ORDER BY created_at ASC, id ASC';
    return db.query(sql, classId ? [classId] : []);
  });
  res.json(data);
}));

app.post('/api/students', wrap(async (req, res) => {
  const { classId, name, studentNo = '', gender = '' } = req.body;
  const cls = classId ? await db.query('SELECT id FROM classes WHERE id = ?', [classId]) : [];
  if (!classId || !cls.length) return bad(res, '班级不存在');
  const n = String(name || '').trim();
  if (!n) return bad(res, '学生姓名不能为空');
  const stu = { id: db.uid('stu'), classId, name: n, studentNo: String(studentNo).trim(), gender: String(gender).trim(), createdAt: new Date() };
  await db.execute(
    'INSERT INTO students (id, class_id, name, student_no, gender, created_at) VALUES (?, ?, ?, ?, ?, ?)',
    [stu.id, stu.classId, stu.name, stu.studentNo, stu.gender, stu.createdAt]
  );
  await cache.invalidate();
  res.status(201).json({ id: stu.id, classId, name: stu.name, studentNo: stu.studentNo, gender: stu.gender });
}));

// Excel/CSV 批量导入（按学号或姓名去重）
app.post('/api/students/import', wrap(async (req, res) => {
  const { classId, students } = req.body;
  const cls = classId ? await db.query('SELECT id FROM classes WHERE id = ?', [classId]) : [];
  if (!classId || !cls.length) return bad(res, '班级不存在');
  if (!Array.isArray(students) || !students.length) return bad(res, '导入数据为空');
  const exist = await db.query('SELECT name, student_no AS studentNo FROM students WHERE class_id = ?', [classId]);
  const nos = new Set(exist.map((s) => s.studentNo).filter(Boolean));
  const names = new Set(exist.map((s) => s.name));
  let added = 0;
  let skipped = 0;
  const now = new Date();
  for (const item of students) {
    const name = String(item.name || '').trim();
    if (!name) { skipped++; continue; }
    const studentNo = String(item.studentNo || '').trim();
    if ((studentNo && nos.has(studentNo)) || names.has(name)) { skipped++; continue; }
    names.add(name);
    if (studentNo) nos.add(studentNo);
    await db.execute(
      'INSERT INTO students (id, class_id, name, student_no, gender, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      [db.uid('stu'), classId, name, studentNo, String(item.gender || '').trim(), now]
    );
    added++;
  }
  await cache.invalidate();
  res.json({ added, skipped });
}));

app.put('/api/students/:id', wrap(async (req, res) => {
  const stu = await db.query('SELECT id FROM students WHERE id = ?', [req.params.id]);
  if (!stu.length) return notFound(res, '学生不存在');
  const { name, studentNo, gender } = req.body;
  const n = String(name || '').trim();
  if (!n) return bad(res, '学生姓名不能为空');
  await db.execute('UPDATE students SET name = ?, student_no = ?, gender = ? WHERE id = ?', [
    n, String(studentNo || '').trim(), String(gender || '').trim(), req.params.id,
  ]);
  await cache.invalidate();
  const updated = await db.query('SELECT id, class_id AS classId, name, student_no AS studentNo, gender FROM students WHERE id = ?', [req.params.id]);
  res.json(updated[0]);
}));

app.delete('/api/students/:id', wrap(async (req, res) => {
  const stu = await db.query('SELECT id, class_id AS classId FROM students WHERE id = ?', [req.params.id]);
  if (!stu.length) return notFound(res, '学生不存在');
  // 同步清理座位表中的该学生占位
  const seat = await db.query('SELECT grid FROM seats WHERE class_id = ?', [stu[0].classId]);
  if (seat.length) {
    const grid = parseJson(seat[0].grid, []).map((row) => row.map((v) => (v === req.params.id ? null : v)));
    await db.execute('UPDATE seats SET grid = ?, updated_at = ? WHERE class_id = ?', [JSON.stringify(grid), new Date(), stu[0].classId]);
  }
  // 成绩通过外键级联删除
  await db.execute('DELETE FROM students WHERE id = ?', [req.params.id]);
  await cache.invalidate();
  res.json({ ok: true });
}));

/* ==================== 考试与成绩 ==================== */

app.get('/api/exams', wrap(async (req, res) => {
  const { classId } = req.query;
  const data = await cache.cachedRead(`exams:${classId || 'all'}`, async () => {
    const sql = classId
      ? 'SELECT id, class_id AS classId, name, exam_date AS date, subjects, created_at AS createdAt FROM exams WHERE class_id = ? ORDER BY created_at ASC, id ASC'
      : 'SELECT id, class_id AS classId, name, exam_date AS date, subjects, created_at AS createdAt FROM exams ORDER BY created_at ASC, id ASC';
    const exams = await db.query(sql, classId ? [classId] : []);
    if (!exams.length) return [];
    const ids = exams.map((e) => e.id);
    const scores = await db.query(
      'SELECT exam_id AS examId, student_id AS studentId, subject, score FROM exam_scores WHERE exam_id IN (?)',
      [ids]
    );
    const byExam = {};
    for (const s of scores) {
      if (!byExam[s.examId]) byExam[s.examId] = {};
      if (!byExam[s.examId][s.studentId]) byExam[s.examId][s.studentId] = {};
      byExam[s.examId][s.studentId][s.subject] = s.score;
    }
    return exams.map((e) => ({ ...e, subjects: parseJson(e.subjects, []), scores: byExam[e.id] || {} }));
  });
  res.json(data);
}));

app.post('/api/exams', wrap(async (req, res) => {
  const { classId, name, date = '', subjects } = req.body;
  const cls = classId ? await db.query('SELECT id FROM classes WHERE id = ?', [classId]) : [];
  if (!classId || !cls.length) return bad(res, '班级不存在');
  const n = String(name || '').trim();
  if (!n) return bad(res, '考试名称不能为空');
  if (!Array.isArray(subjects) || !subjects.length) return bad(res, '至少添加一个科目');
  const subs = subjects.map((s) => String(s).trim()).filter(Boolean);
  if (!subs.length) return bad(res, '科目名称不能为空');
  const exam = { id: db.uid('exam'), classId, name: n, date: String(date), subjects: subs, createdAt: new Date() };
  await db.execute('INSERT INTO exams (id, class_id, name, exam_date, subjects, created_at) VALUES (?, ?, ?, ?, ?, ?)', [
    exam.id, exam.classId, exam.name, exam.date, JSON.stringify(exam.subjects), exam.createdAt,
  ]);
  await cache.invalidate();
  res.status(201).json({ ...exam, scores: {} });
}));

app.put('/api/exams/:id', wrap(async (req, res) => {
  const examRows = await db.query('SELECT id, class_id AS classId FROM exams WHERE id = ?', [req.params.id]);
  if (!examRows.length) return notFound(res, '考试不存在');
  const { name, date, subjects, scores } = req.body;
  if (name !== undefined) {
    const n = String(name || '').trim();
    if (!n) return bad(res, '考试名称不能为空');
    await db.execute('UPDATE exams SET name = ? WHERE id = ?', [n, req.params.id]);
  }
  if (date !== undefined) await db.execute('UPDATE exams SET exam_date = ? WHERE id = ?', [String(date), req.params.id]);
  if (subjects !== undefined) {
    if (!Array.isArray(subjects) || !subjects.length) return bad(res, '至少保留一个科目');
    const subs = subjects.map((s) => String(s).trim()).filter(Boolean);
    if (!subs.length) return bad(res, '科目名称不能为空');
    await db.execute('UPDATE exams SET subjects = ? WHERE id = ?', [JSON.stringify(subs), req.params.id]);
  }
  if (scores !== undefined && scores && typeof scores === 'object' && !Array.isArray(scores)) {
    await db.transaction(async (conn) => {
      await conn.execute('DELETE FROM exam_scores WHERE exam_id = ?', [req.params.id]);
      for (const [studentId, subjectsMap] of Object.entries(scores)) {
        for (const [subject, score] of Object.entries(subjectsMap || {})) {
          if (score === null || score === undefined || score === '') continue;
          await conn.execute(
            'INSERT INTO exam_scores (exam_id, student_id, subject, score) VALUES (?, ?, ?, ?)',
            [req.params.id, studentId, subject, Number(score)]
          );
        }
      }
    });
  }
  await cache.invalidate();
  const updated = await db.query(
    'SELECT id, class_id AS classId, name, exam_date AS date, subjects, created_at AS createdAt FROM exams WHERE id = ?',
    [req.params.id]
  );
  const e = updated[0];
  const scoreRows = await db.query('SELECT student_id AS studentId, subject, score FROM exam_scores WHERE exam_id = ?', [req.params.id]);
  const scoresObj = {};
  for (const s of scoreRows) {
    if (!scoresObj[s.studentId]) scoresObj[s.studentId] = {};
    scoresObj[s.studentId][s.subject] = s.score;
  }
  res.json({ ...e, subjects: parseJson(e.subjects, []), scores: scoresObj });
}));

app.delete('/api/exams/:id', wrap(async (req, res) => {
  const exists = await db.query('SELECT id FROM exams WHERE id = ?', [req.params.id]);
  if (!exists.length) return notFound(res, '考试不存在');
  await db.execute('DELETE FROM exams WHERE id = ?', [req.params.id]);
  await cache.invalidate();
  res.json({ ok: true });
}));

/* ==================== 抽奖 ==================== */

app.post('/api/lottery/draw', wrap(async (req, res) => {
  const { classId, count = 1, excludeIds = [] } = req.body;
  const cls = classId ? await db.query('SELECT id FROM classes WHERE id = ?', [classId]) : [];
  if (!classId || !cls.length) return bad(res, '班级不存在');
  const n = Math.max(1, Math.min(50, Number(count) || 1));
  const exclude = new Set(Array.isArray(excludeIds) ? excludeIds : []);
  const pool = await db.query(
    'SELECT id, class_id AS classId, name, student_no AS studentNo, gender FROM students WHERE class_id = ?',
    [classId]
  );
  const available = pool.filter((s) => !exclude.has(s.id));
  if (!available.length) return bad(res, '没有可抽取的学生');
  // Fisher-Yates 洗牌，保证公平
  const shuffled = [...available];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  const take = Math.min(n, shuffled.length);
  const winners = shuffled.slice(0, take);
  const record = { id: db.uid('lot'), classId, ts: new Date(), count: take, requested: n };
  await db.transaction(async (conn) => {
    await conn.execute('INSERT INTO lotteries (id, class_id, draw_time, requested, drawn_count) VALUES (?, ?, ?, ?, ?)', [
      record.id, record.classId, record.ts, record.requested, record.count,
    ]);
    for (let i = 0; i < winners.length; i++) {
      await conn.execute('INSERT INTO lottery_winners (lottery_id, student_id, seq) VALUES (?, ?, ?)', [
        record.id, winners[i].id, i,
      ]);
    }
  });
  await cache.invalidate();
  res.json({ winners, partial: take < n, recordId: record.id });
}));

app.get('/api/lottery', wrap(async (req, res) => {
  const { classId } = req.query;
  const sql = classId
    ? 'SELECT id, class_id AS classId, draw_time AS ts, requested, drawn_count AS count FROM lotteries WHERE class_id = ? ORDER BY draw_time DESC'
    : 'SELECT id, class_id AS classId, draw_time AS ts, requested, drawn_count AS count FROM lotteries ORDER BY draw_time DESC';
  const list = await db.query(sql, classId ? [classId] : []);
  if (!list.length) return res.json([]);
  const ids = list.map((l) => l.id);
  const winners = await db.query('SELECT lottery_id AS lotteryId, student_id AS studentId FROM lottery_winners WHERE lottery_id IN (?)', [ids]);
  const byLottery = {};
  for (const w of winners) {
    if (!byLottery[w.lotteryId]) byLottery[w.lotteryId] = [];
    byLottery[w.lotteryId].push(w.studentId);
  }
  res.json(list.map((l) => ({ ...l, winnerIds: byLottery[l.id] || [] })));
}));

app.delete('/api/lottery', wrap(async (req, res) => {
  if (req.query.classId) {
    await db.execute('DELETE FROM lotteries WHERE class_id = ?', [req.query.classId]);
  } else {
    await db.execute('DELETE FROM lotteries');
  }
  await cache.invalidate();
  res.json({ ok: true });
}));

app.delete('/api/lottery/:id', wrap(async (req, res) => {
  const exists = await db.query('SELECT id FROM lotteries WHERE id = ?', [req.params.id]);
  if (!exists.length) return notFound(res, '记录不存在');
  await db.execute('DELETE FROM lotteries WHERE id = ?', [req.params.id]);
  await cache.invalidate();
  res.json({ ok: true });
}));

/* ==================== 座位表 ==================== */

const emptyGrid = (rows, cols) => Array.from({ length: rows }, () => Array(cols).fill(null));

app.get('/api/seats/:classId', wrap(async (req, res) => {
  const { classId } = req.params;
  const rows = await db.query(
    'SELECT seat_rows AS `rows`, seat_cols AS `cols`, blocked, grid, updated_at AS updatedAt FROM seats WHERE class_id = ?',
    [classId]
  );
  if (rows.length) {
    const r = rows[0];
    return res.json({ rows: r.rows, cols: r.cols, blocked: parseJson(r.blocked, []), seats: parseJson(r.grid, []), updatedAt: r.updatedAt });
  }
  const cls = await db.query('SELECT id FROM classes WHERE id = ?', [classId]);
  if (!cls.length) return notFound(res, '班级不存在');
  const def = { rows: 6, cols: 8, blocked: [], seats: emptyGrid(6, 8), updatedAt: new Date() };
  await db.execute(
    'INSERT INTO seats (class_id, seat_rows, seat_cols, blocked, grid, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
    [classId, def.rows, def.cols, JSON.stringify(def.blocked), JSON.stringify(def.seats), def.updatedAt]
  );
  res.json(def);
}));

app.put('/api/seats/:classId', wrap(async (req, res) => {
  const { classId } = req.params;
  const cls = await db.query('SELECT id FROM classes WHERE id = ?', [classId]);
  if (!cls.length) return notFound(res, '班级不存在');
  const { rows, cols, blocked = [], seats } = req.body;
  if (!Number.isInteger(rows) || !Number.isInteger(cols) || rows < 1 || rows > 20 || cols < 1 || cols > 20) {
    return bad(res, '行列数不合法（1-20）');
  }
  if (!Array.isArray(seats) || seats.length !== rows || seats.some((r) => !Array.isArray(r) || r.length !== cols)) {
    return bad(res, '座位数据格式不正确');
  }
  const stuRows = await db.query('SELECT id FROM students WHERE class_id = ?', [classId]);
  const ids = new Set(stuRows.map((s) => s.id));
  const cleanSeats = seats.map((row) => row.map((v) => (typeof v === 'string' && ids.has(v) ? v : null)));
  const cleanBlocked = (Array.isArray(blocked) ? blocked : [])
    .filter((b) => Array.isArray(b) && b.length === 2 && b[0] >= 0 && b[0] < rows && b[1] >= 0 && b[1] < cols)
    .map((b) => [b[0], b[1]]);
  const updatedAt = new Date();
  await db.execute(
    'INSERT INTO seats (class_id, seat_rows, seat_cols, blocked, grid, updated_at) VALUES (?, ?, ?, ?, ?, ?) ' +
    'ON DUPLICATE KEY UPDATE seat_rows = VALUES(seat_rows), seat_cols = VALUES(seat_cols), blocked = VALUES(blocked), grid = VALUES(grid), updated_at = VALUES(updated_at)',
    [classId, rows, cols, JSON.stringify(cleanBlocked), JSON.stringify(cleanSeats), updatedAt]
  );
  await cache.invalidate();
  res.json({ rows, cols, blocked: cleanBlocked, seats: cleanSeats, updatedAt });
}));

/* ==================== AI 成绩分析（服务端代理，密钥不暴露给浏览器） ==================== */

const LLM_BASE_URL = (process.env.LLM_BASE_URL || 'https://apihub.agnes-ai.com/v1').replace(/\/+$/, '');
const LLM_API_KEY = process.env.LLM_API_KEY || '';
const LLM_MODEL = process.env.LLM_MODEL || 'agnes-2.5-pro-beta';

app.get('/api/ai/status', (req, res) => {
  res.json({ configured: Boolean(LLM_API_KEY), model: LLM_API_KEY ? LLM_MODEL : null });
});

app.post('/api/ai/analyze', wrap(async (req, res) => {
  const { classId, examId, stats, question } = req.body;
  const cls = classId ? await db.query('SELECT id FROM classes WHERE id = ?', [classId]) : [];
  if (!classId || !cls.length) return bad(res, '班级不存在');
  const examRows = await db.query('SELECT id, name, exam_date AS date, subjects FROM exams WHERE id = ?', [examId]);
  if (!examRows.length) return notFound(res, '考试不存在');
  if (!stats || typeof stats !== 'object') return bad(res, '缺少统计数据');
  if (!LLM_API_KEY) return res.status(503).json({ error: 'AI 功能未配置：请在服务端设置 LLM_API_KEY 环境变量' });

  // Redis 限流：每个 IP 每分钟最多 5 次
  const ip = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.ip || req.socket.remoteAddress || 'unknown';
  const limited = await cache.aiRateLimit(ip, 5);
  if (limited) return res.status(429).json({ error: 'AI 分析调用过于频繁，请 1 分钟后再试' });

  const classRow = await db.query('SELECT name FROM classes WHERE id = ?', [classId]);
  const className = classRow[0].name;
  const exam = { name: examRows[0].name, date: examRows[0].date, subjects: parseJson(examRows[0].subjects, []) };

  // Redis 结果缓存：相同班级+考试+统计内容在 24 小时内直接复用，节省额度
  const sign = crypto.createHash('sha1').update(JSON.stringify({ classId, examId, stats, question })).digest('hex');
  const resultKey = `ai:result:${sign}`;
  const cachedResult = await cache.get(resultKey);
  if (cachedResult) return res.json(cachedResult);

  const systemPrompt =
    '你是一位资深的中学教学数据分析专家，擅长根据班级考试数据给出专业、具体、可落地的教学建议。' +
    '请使用简体中文，用 Markdown 格式输出（可用小标题、加粗、列表），条理清晰，避免空话套话，总长度控制在 800 字以内。';

  const userPrompt =
    `请分析以下班级考试数据并给出教学建议：\n\n` +
    `班级：${className}\n考试：${exam.name}${exam.date ? `（${exam.date}）` : ''}\n科目：${(exam.subjects || []).join('、')}\n\n` +
    `统计数据（JSON）：\n${JSON.stringify(stats, null, 2)}\n\n` +
    `请从这几方面分析：\n` +
    `1. 整体学情概览（均分水平、离散程度、分布形态）\n` +
    `2. 各科对比（强弱科、可能的原因）\n` +
    `3. 分层情况（优秀生/临界生/学困生，点名需重点关注的学生）\n` +
    `4. 具体教学建议（3-5 条，可操作）\n` +
    (question ? `\n老师特别关注的问题：${String(question).slice(0, 500)}` : '');

  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  // 429/5xx 自动重试（指数退避，最多 3 次，尊重 Retry-After 头）
  const MAX_RETRY = 3;
  let retryDelay = 3000;
  let r;
  let lastStatus = 0;
  let lastBody = '';
  for (let attempt = 0; attempt <= MAX_RETRY; attempt++) {
    if (attempt > 0) await sleep(retryDelay);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 120000);
    try {
      r = await fetch(`${LLM_BASE_URL}/chat/completions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${LLM_API_KEY}` },
        body: JSON.stringify({
          model: LLM_MODEL,
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: userPrompt },
          ],
          temperature: 0.5,
        }),
        signal: controller.signal,
      });
    } catch (err) {
      clearTimeout(timer);
      if (err.name === 'AbortError') return res.status(504).json({ error: 'AI 分析超时，请稍后重试' });
      return res.status(502).json({ error: '调用大模型失败：' + err.message });
    }
    clearTimeout(timer);
    if (r.ok) break;
    lastStatus = r.status;
    lastBody = await r.text().catch(() => '');
    if (r.status === 429 || r.status >= 500) {
      // 读 Retry-After（秒），否则指数退避 3s → 6s → 12s
      const ra = Number(r.headers.get('retry-after'));
      retryDelay = Number.isFinite(ra) && ra > 0 ? Math.min(ra * 1000, 30000) : 3000 * 2 ** (attempt - 1) || 3000;
      continue; // 重试
    }
    break; // 其他错误码（401/400 等）不重试
  }
  if (r && r.ok) {
    try {
      const data = await r.json();
      const content = data?.choices?.[0]?.message?.content;
      if (!content) return res.status(502).json({ error: '大模型未返回有效内容，请重试' });
      const result = { content, model: data.model || LLM_MODEL };
      await cache.set(resultKey, result, 86400);
      return res.json(result);
    } catch (err) {
      return res.status(502).json({ error: '解析大模型响应失败：' + err.message });
    }
  }
  if (lastStatus === 429) {
    return res.status(429).json({
      error: '大模型 API 触发限流（免费额度已用完或请求过于频繁）。已自动重试 3 次仍失败。请等几分钟后再试；若频繁出现，说明当前 API Key 是免费套餐（free tier），需要到 apihub.agnes-ai.com 升级为 Token Plan 或更换更高额度的 API Key。',
    });
  }
  if (lastStatus === 401 || lastStatus === 403) {
    return res.status(502).json({ error: '大模型 API Key 无效或已失效，请检查服务器 .env 中的 LLM_API_KEY' });
  }
  res.status(502).json({ error: `大模型服务返回错误 (${lastStatus})：${lastBody.slice(0, 200)}` });
}));

/* ==================== 健康检查 ==================== */

app.get('/api/health', async (req, res) => {
  let dbOk = false;
  let redisOk = false;
  try { await db.query('SELECT 1'); dbOk = true; } catch (_) { /* ignore */ }
  try { redisOk = Boolean(await cache.ping()); } catch (_) { /* ignore */ }
  res.json({ status: dbOk && redisOk ? 'ok' : 'degraded', mysql: dbOk, redis: redisOk });
});

/* 前后端分离后，后端只提供 API */
app.use((req, res) => res.status(404).json({ error: '接口不存在' }));

app.listen(PORT, '127.0.0.1', () => {
  console.log(`[teacher-assistant] API 服务已启动(仅本机): http://127.0.0.1:${PORT}`);
});



