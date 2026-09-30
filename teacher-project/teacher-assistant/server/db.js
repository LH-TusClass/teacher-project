const mysql = require('mysql2/promise');

// MySQL 连接池（配置来自环境变量 / .env）
const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER || 'teacher',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'teacher_assistant',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  timezone: 'Z', // 时间统一按 UTC 存储/读取，输出与旧版 ISO 格式一致
  charset: 'utf8mb4',
});

async function query(sql, params) {
  const [rows] = await pool.query(sql, params);
  return rows;
}

async function execute(sql, params) {
  const [result] = await pool.execute(sql, params);
  return result;
}

async function transaction(fn) {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const result = await fn(conn);
    await conn.commit();
    return result;
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}

function uid(prefix) {
  return `${prefix}_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
}

module.exports = { pool, query, execute, transaction, uid };
