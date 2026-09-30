-- 教师助手数据库结构（MySQL 8，utf8mb4）
-- 由 server/migrate.js 或手工执行，创建全部业务表

CREATE TABLE IF NOT EXISTS classes (
  id         VARCHAR(40)  NOT NULL COMMENT '班级ID',
  name       VARCHAR(100) NOT NULL COMMENT '班级名称',
  created_at DATETIME(3)  NOT NULL COMMENT '创建时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_classes_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='班级表';

CREATE TABLE IF NOT EXISTS students (
  id         VARCHAR(40)  NOT NULL COMMENT '学生ID',
  class_id   VARCHAR(40)  NOT NULL COMMENT '所属班级ID',
  name       VARCHAR(100) NOT NULL COMMENT '学生姓名',
  student_no VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '学号',
  gender     VARCHAR(8)   NOT NULL DEFAULT '' COMMENT '性别',
  created_at DATETIME(3)  NOT NULL COMMENT '创建时间',
  PRIMARY KEY (id),
  KEY idx_students_class (class_id),
  CONSTRAINT fk_students_class FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='学生表';

CREATE TABLE IF NOT EXISTS exams (
  id         VARCHAR(40)  NOT NULL COMMENT '考试ID',
  class_id   VARCHAR(40)  NOT NULL COMMENT '班级ID',
  name       VARCHAR(100) NOT NULL COMMENT '考试名称',
  exam_date  VARCHAR(20)  NOT NULL DEFAULT '' COMMENT '考试日期',
  subjects   JSON         NOT NULL COMMENT '科目列表（JSON数组）',
  created_at DATETIME(3)  NOT NULL COMMENT '创建时间',
  PRIMARY KEY (id),
  KEY idx_exams_class (class_id),
  CONSTRAINT fk_exams_class FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='考试表';

CREATE TABLE IF NOT EXISTS exam_scores (
  exam_id    VARCHAR(40) NOT NULL COMMENT '考试ID',
  student_id VARCHAR(40) NOT NULL COMMENT '学生ID',
  subject    VARCHAR(50) NOT NULL COMMENT '科目',
  score      DOUBLE      NOT NULL COMMENT '分数',
  PRIMARY KEY (exam_id, student_id, subject),
  KEY idx_scores_student (student_id),
  CONSTRAINT fk_scores_exam FOREIGN KEY (exam_id) REFERENCES exams (id) ON DELETE CASCADE,
  CONSTRAINT fk_scores_student FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='考试成绩表';

CREATE TABLE IF NOT EXISTS lotteries (
  id          VARCHAR(40) NOT NULL COMMENT '抽奖记录ID',
  class_id    VARCHAR(40) NOT NULL COMMENT '班级ID',
  draw_time   DATETIME(3) NOT NULL COMMENT '抽奖时间',
  requested   INT         NOT NULL DEFAULT 0 COMMENT '请求抽取人数',
  drawn_count INT         NOT NULL DEFAULT 0 COMMENT '实际抽取人数',
  PRIMARY KEY (id),
  KEY idx_lotteries_class (class_id, draw_time),
  CONSTRAINT fk_lotteries_class FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='抽奖记录表';

CREATE TABLE IF NOT EXISTS lottery_winners (
  lottery_id VARCHAR(40) NOT NULL COMMENT '抽奖记录ID',
  student_id VARCHAR(40) NOT NULL COMMENT '中奖学生ID',
  seq        INT         NOT NULL COMMENT '中奖顺序',
  PRIMARY KEY (lottery_id, seq),
  KEY idx_winners_student (student_id),
  CONSTRAINT fk_winners_lottery FOREIGN KEY (lottery_id) REFERENCES lotteries (id) ON DELETE CASCADE,
  CONSTRAINT fk_winners_student FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='抽奖中奖学生表';

CREATE TABLE IF NOT EXISTS seats (
  class_id   VARCHAR(40) NOT NULL COMMENT '班级ID',
  seat_rows  INT         NOT NULL COMMENT '座位行数',
  seat_cols  INT         NOT NULL COMMENT '座位列数',
  blocked    JSON        NOT NULL COMMENT '禁座坐标（JSON数组）',
  grid       JSON        NOT NULL COMMENT '座位矩阵（学生ID，JSON二维数组）',
  updated_at DATETIME(3) NOT NULL COMMENT '更新时间',
  PRIMARY KEY (class_id),
  CONSTRAINT fk_seats_class FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='座位表';
