require('dotenv').config();
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');

// 一次性迁移脚本：将 data/db.json 的数据导入 MySQL（幂等：会重建全部业务表）
async function main() {
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT) || 3306,
    user: process.env.DB_USER || 'teacher',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'teacher_assistant',
    multipleStatements: true,
    charset: 'utf8mb4',
    timezone: 'Z',
  });

  const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
  const statements = schema
    .split(';')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);

  console.log('重建业务表...');
  await conn.query('SET FOREIGN_KEY_CHECKS = 0');
  await conn.query('DROP TABLE IF EXISTS lottery_winners');
  await conn.query('DROP TABLE IF EXISTS lotteries');
  await conn.query('DROP TABLE IF EXISTS seats');
  await conn.query('DROP TABLE IF EXISTS exam_scores');
  await conn.query('DROP TABLE IF EXISTS exams');
  await conn.query('DROP TABLE IF EXISTS students');
  await conn.query('DROP TABLE IF EXISTS classes');
  for (const stmt of statements) await conn.query(stmt);
  await conn.query('SET FOREIGN_KEY_CHECKS = 1');

  // 迁移完成后原文件已归档为 db.json.migrated.bak，二者均可读取
  const dbFile = ['db.json', 'db.json.migrated.bak']
    .map((n) => path.join(__dirname, '..', 'data', n))
    .find((p) => fs.existsSync(p));
  if (!dbFile) throw new Error('未找到可迁移的 data/db.json 或 data/db.json.migrated.bak');
  const raw = JSON.parse(fs.readFileSync(dbFile, 'utf8'));

  console.log('迁移班级...');
  for (const c of raw.classes || []) {
    await conn.query('INSERT INTO classes (id, name, created_at) VALUES (?, ?, ?)', [
      c.id, c.name, new Date(c.createdAt || Date.now()),
    ]);
  }

  console.log('迁移学生...');
  for (const s of raw.students || []) {
    await conn.query('INSERT INTO students (id, class_id, name, student_no, gender, created_at) VALUES (?, ?, ?, ?, ?, ?)', [
      s.id, s.classId, s.name, s.studentNo || '', s.gender || '', new Date(),
    ]);
  }

  console.log('迁移考试与成绩...');
  for (const e of raw.exams || []) {
    await conn.query('INSERT INTO exams (id, class_id, name, exam_date, subjects, created_at) VALUES (?, ?, ?, ?, ?, ?)', [
      e.id, e.classId, e.name, e.date || '', JSON.stringify(e.subjects || []), new Date(),
    ]);
    for (const [studentId, subjectsMap] of Object.entries(e.scores || {})) {
      for (const [subject, score] of Object.entries(subjectsMap || {})) {
        if (score === null || score === undefined || score === '') continue;
        await conn.query('INSERT INTO exam_scores (exam_id, student_id, subject, score) VALUES (?, ?, ?, ?)', [
          e.id, studentId, subject, Number(score),
        ]);
      }
    }
  }

  console.log('迁移抽奖记录...');
  for (const l of raw.lotteries || []) {
    const requested = l.requested != null ? l.requested : (l.winnerIds || []).length;
    const drawn = l.count != null ? l.count : (l.winnerIds || []).length;
    await conn.query('INSERT INTO lotteries (id, class_id, draw_time, requested, drawn_count) VALUES (?, ?, ?, ?, ?)', [
      l.id, l.classId, new Date(l.ts || Date.now()), requested, drawn,
    ]);
    for (let i = 0; i < (l.winnerIds || []).length; i++) {
      await conn.query('INSERT INTO lottery_winners (lottery_id, student_id, seq) VALUES (?, ?, ?)', [
        l.id, l.winnerIds[i], i,
      ]);
    }
  }

  console.log('迁移座位表...');
  for (const [classId, seat] of Object.entries(raw.seats || {})) {
    await conn.query('INSERT INTO seats (class_id, seat_rows, seat_cols, blocked, grid, updated_at) VALUES (?, ?, ?, ?, ?, ?)', [
      classId, seat.rows, seat.cols, JSON.stringify(seat.blocked || []), JSON.stringify(seat.seats || []), new Date(seat.updatedAt || Date.now()),
    ]);
  }

  await conn.end();
  console.log('迁移完成 ✓ 数据已由 JSON 文件迁移到 MySQL（teacher_assistant 库）');
}

main().catch((err) => {
  console.error('迁移失败:', err.message);
  process.exit(1);
});


