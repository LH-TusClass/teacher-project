-- ============================================================
-- 面试系统 (interview_db) 数据库初始化脚本
-- 适用: MySQL 8.0+   字符集: utf8mb4 / utf8mb4_unicode_ci
-- 说明: 主键 id 由应用层雪花算法生成 (MyBatis-Plus ASSIGN_ID)
--       初始管理员 admin/admin123 由后端 DataInitializer 自动创建
-- ============================================================

CREATE DATABASE IF NOT EXISTS interview_db
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE interview_db;

-- ---------------- 系统域 ----------------

CREATE TABLE sys_dept (
  id            BIGINT       NOT NULL COMMENT '主键',
  name          VARCHAR(64)  NOT NULL COMMENT '部门名称',
  parent_id     BIGINT       NOT NULL DEFAULT 0 COMMENT '上级部门ID,0=顶级',
  sort          INT          NOT NULL DEFAULT 0 COMMENT '显示顺序',
  status        TINYINT      NOT NULL DEFAULT 1 COMMENT '1启用 0停用',
  created_by    BIGINT       NULL,
  created_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_by    BIGINT       NULL,
  updated_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  deleted       TINYINT      NOT NULL DEFAULT 0 COMMENT '逻辑删除 0否 1是',
  PRIMARY KEY (id),
  KEY idx_parent (parent_id, deleted)
) ENGINE=InnoDB COMMENT='部门';

CREATE TABLE sys_user (
  id              BIGINT       NOT NULL COMMENT '主键',
  username        VARCHAR(64)  NOT NULL COMMENT '登录账号',
  password        VARCHAR(100) NOT NULL COMMENT 'BCrypt密文',
  real_name       VARCHAR(64)  NOT NULL COMMENT '姓名',
  phone           VARCHAR(64)  NULL COMMENT '手机号(AES加密存储)',
  email           VARCHAR(128) NULL,
  dept_id         BIGINT       NULL COMMENT '所属部门',
  status          TINYINT      NOT NULL DEFAULT 1 COMMENT '1启用 0停用',
  last_login_time DATETIME     NULL COMMENT '最近登录时间',
  created_by      BIGINT       NULL,
  created_time    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by      BIGINT       NULL,
  updated_time    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted         TINYINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_username (username),
  KEY idx_dept (dept_id, deleted)
) ENGINE=InnoDB COMMENT='后台用户';

CREATE TABLE sys_role (
  id           BIGINT      NOT NULL,
  code         VARCHAR(64) NOT NULL COMMENT '角色编码',
  name         VARCHAR(64) NOT NULL COMMENT '角色名称',
  remark       VARCHAR(255) NULL,
  created_by   BIGINT      NULL,
  created_time DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by   BIGINT      NULL,
  updated_time DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted      TINYINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code)
) ENGINE=InnoDB COMMENT='角色';

CREATE TABLE sys_permission (
  id           BIGINT       NOT NULL,
  parent_id    BIGINT       NOT NULL DEFAULT 0 COMMENT '上级权限,0=根',
  name         VARCHAR(64)  NOT NULL COMMENT '权限名称',
  code         VARCHAR(128) NOT NULL COMMENT '权限标识,如 position:add',
  type         TINYINT      NOT NULL COMMENT '1菜单 2按钮',
  path         VARCHAR(255) NULL COMMENT '前端路由/接口路径',
  sort         INT          NOT NULL DEFAULT 0,
  created_by   BIGINT       NULL,
  created_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by   BIGINT       NULL,
  updated_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted      TINYINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_code (code),
  KEY idx_parent (parent_id)
) ENGINE=InnoDB COMMENT='权限(菜单/按钮)';

CREATE TABLE sys_user_role (
  user_id BIGINT NOT NULL,
  role_id BIGINT NOT NULL,
  PRIMARY KEY (user_id, role_id)
) ENGINE=InnoDB COMMENT='用户-角色';

CREATE TABLE sys_role_permission (
  role_id        BIGINT NOT NULL,
  permission_id  BIGINT NOT NULL,
  PRIMARY KEY (role_id, permission_id)
) ENGINE=InnoDB COMMENT='角色-权限';
CREATE TABLE sys_dict_type (
  id           BIGINT      NOT NULL,
  type_code    VARCHAR(64) NOT NULL COMMENT '字典类型编码',
  name         VARCHAR(64) NOT NULL COMMENT '字典名称',
  remark       VARCHAR(255) NULL,
  created_by   BIGINT      NULL,
  created_time DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by   BIGINT      NULL,
  updated_time DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted      TINYINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_type (type_code)
) ENGINE=InnoDB COMMENT='字典类型';

CREATE TABLE sys_dict_data (
  id           BIGINT       NOT NULL,
  type_code    VARCHAR(64)  NOT NULL COMMENT '字典类型编码',
  label        VARCHAR(64)  NOT NULL COMMENT '显示文本',
  value        VARCHAR(64)  NOT NULL COMMENT '值',
  sort         INT          NOT NULL DEFAULT 0,
  status       TINYINT      NOT NULL DEFAULT 1 COMMENT '1启用 0停用',
  created_by   BIGINT       NULL,
  created_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by   BIGINT       NULL,
  updated_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted      TINYINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_type_value (type_code, value)
) ENGINE=InnoDB COMMENT='字典项';

CREATE TABLE sys_notify (
  id           BIGINT        NOT NULL,
  user_id      BIGINT        NOT NULL COMMENT '接收人(后台用户)',
  side         TINYINT       NOT NULL DEFAULT 1 COMMENT '1后台 2候选人',
  title        VARCHAR(128)  NOT NULL,
  content      VARCHAR(1000) NOT NULL,
  type         VARCHAR(32)   NOT NULL COMMENT '面试邀请/改约/Offer/结果等',
  ref_id       BIGINT        NULL COMMENT '关联业务ID',
  read_time    DATETIME      NULL,
  created_by   BIGINT        NULL,
  created_time DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by   BIGINT        NULL,
  updated_time DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted      TINYINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_user_read (user_id, read_time, deleted)
) ENGINE=InnoDB COMMENT='站内通知';

CREATE TABLE sys_operation_log (
  id           BIGINT        NOT NULL,
  user_id      BIGINT        NULL,
  username     VARCHAR(64)   NULL,
  module       VARCHAR(64)   NOT NULL COMMENT '模块',
  action       VARCHAR(64)   NOT NULL COMMENT '操作',
  detail       VARCHAR(2000) NULL COMMENT '操作详情JSON',
  ip           VARCHAR(64)   NULL,
  created_by   BIGINT        NULL,
  created_time DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by   BIGINT        NULL,
  updated_time DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted      TINYINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_user_time (user_id, created_time)
) ENGINE=InnoDB COMMENT='操作日志';

-- ---------------- 招聘域 ----------------

CREATE TABLE candidate (
  id                 BIGINT      NOT NULL,
  phone_enc          VARCHAR(128) NOT NULL COMMENT '手机号(AES加密)',
  phone_tail         CHAR(4)     NOT NULL COMMENT '手机尾号(检索用)',
  name               VARCHAR(64) NOT NULL,
  gender             TINYINT     NULL COMMENT '字典gender: 1男 2女',
  birth_date         DATE        NULL,
  email              VARCHAR(128) NULL,
  location           VARCHAR(64) NULL COMMENT '现居住地',
  expected_position  VARCHAR(128) NULL COMMENT '期望职位',
  expected_city      VARCHAR(64)  NULL,
  expected_salary    VARCHAR(32)  NULL COMMENT '期望薪资',
  source             VARCHAR(32)  NULL COMMENT '字典source: 渠道',
  status             TINYINT     NOT NULL DEFAULT 1 COMMENT '1正常 0禁用',
  password           VARCHAR(100) NOT NULL COMMENT '候选人登录密码(BCrypt)',
  last_active_time   DATETIME    NULL,
  created_by         BIGINT      NULL,
  created_time       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by         BIGINT      NULL,
  updated_time       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted            TINYINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_phone_enc (phone_enc),
  KEY idx_name (name),
  KEY idx_tail (phone_tail)
) ENGINE=InnoDB COMMENT='候选人';

CREATE TABLE candidate_resume (
  id             BIGINT        NOT NULL,
  candidate_id   BIGINT        NOT NULL,
  attachment_key VARCHAR(255)  NULL COMMENT '简历附件对象存储key',
  attachment_url VARCHAR(512)  NULL,
  skills         VARCHAR(1000) NULL COMMENT '技能/证书等自由文本',
  locked         TINYINT       NOT NULL DEFAULT 0 COMMENT '锁定后关键字段不可改',
  created_by     BIGINT       NULL,
  created_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by     BIGINT       NULL,
  updated_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted        TINYINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_candidate (candidate_id, deleted)
) ENGINE=InnoDB COMMENT='简历';

CREATE TABLE resume_experience (
  id           BIGINT        NOT NULL,
  resume_id    BIGINT        NOT NULL,
  company      VARCHAR(128)  NOT NULL,
  position     VARCHAR(128)  NULL,
  start_date   DATE          NULL,
  end_date     DATE          NULL,
  content      VARCHAR(2000) NULL,
  created_by   BIGINT        NULL,
  created_time DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by   BIGINT        NULL,
  updated_time DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted      TINYINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_resume (resume_id, deleted)
) ENGINE=InnoDB COMMENT='工作经历';

CREATE TABLE resume_education (
  id           BIGINT       NOT NULL,
  resume_id    BIGINT       NOT NULL,
  school       VARCHAR(128) NOT NULL,
  major        VARCHAR(128) NULL,
  degree       VARCHAR(32)  NULL COMMENT '字典education',
  start_date   DATE         NULL,
  end_date     DATE         NULL,
  created_by   BIGINT       NULL,
  created_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by   BIGINT       NULL,
  updated_time DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted      TINYINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_resume (resume_id, deleted)
) ENGINE=InnoDB COMMENT='教育经历';

CREATE TABLE position (
  id            BIGINT        NOT NULL,
  dept_id       BIGINT        NULL,
  name          VARCHAR(128)  NOT NULL,
  city          VARCHAR(64)   NOT NULL,
  headcount     INT           NOT NULL DEFAULT 1,
  salary_min    DECIMAL(12,0) NULL COMMENT '月薪下限(元)',
  salary_max    DECIMAL(12,0) NULL,
  requirement   VARCHAR(2000) NULL COMMENT '任职要求',
  jd            VARCHAR(4000) NULL COMMENT '职位描述',
  status        TINYINT       NOT NULL DEFAULT 1 COMMENT '1招聘中 2暂停 3已关闭',
  created_by    BIGINT        NULL,
  created_time  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by    BIGINT        NULL,
  updated_time  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted       TINYINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_status_city (status, city),
  KEY idx_name (name)
) ENGINE=InnoDB COMMENT='职位';

CREATE TABLE position_interview_template (
  id           BIGINT      NOT NULL,
  position_id  BIGINT      NOT NULL,
  round_no     INT         NOT NULL COMMENT '轮次序号,从1开始',
  round_type   VARCHAR(32) NOT NULL COMMENT '字典round_type: phone/first/second/final',
  remark       VARCHAR(255) NULL,
  created_by   BIGINT      NULL,
  created_time DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by   BIGINT      NULL,
  updated_time DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted      TINYINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_position_round (position_id, round_no, deleted)
) ENGINE=InnoDB COMMENT='职位面试轮次模板';

CREATE TABLE application (
  id            BIGINT      NOT NULL,
  candidate_id  BIGINT      NOT NULL,
  position_id   BIGINT      NOT NULL,
  status        TINYINT     NOT NULL DEFAULT 1 COMMENT '1已投递 2筛选中 3面试中 4已通过 5未通过 6已发Offer 7Offer已接受 8Offer已拒绝 9已归档',
  current_round INT         NOT NULL DEFAULT 0 COMMENT '当前面试轮次',
  reject_reason VARCHAR(255) NULL,
  apply_time    DATETIME    NOT NULL COMMENT '投递时间',
  created_by    BIGINT      NULL,
  created_time  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by    BIGINT      NULL,
  updated_time  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted       TINYINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_candidate_position (candidate_id, position_id, deleted),
  KEY idx_status_position (status, position_id, updated_time)
) ENGINE=InnoDB COMMENT='职位申请';

CREATE TABLE application_status_log (
  id            BIGINT       NOT NULL,
  application_id BIGINT      NOT NULL,
  from_status   TINYINT      NULL,
  to_status     TINYINT      NOT NULL,
  operator_id   BIGINT       NULL,
  reason        VARCHAR(255) NULL,
  created_by    BIGINT       NULL,
  created_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',
  updated_by    BIGINT       NULL,
  updated_time  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted       TINYINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_application (application_id, created_time)
) ENGINE=InnoDB COMMENT='申请状态流水';

CREATE TABLE interview (
  id             BIGINT       NOT NULL,
  application_id BIGINT      NOT NULL,
  round_no       INT         NOT NULL COMMENT '轮次',
  round_type     VARCHAR(32) NOT NULL,
  start_time     DATETIME    NOT NULL,
  duration_min   INT         NOT NULL DEFAULT 60,
  type           TINYINT     NOT NULL COMMENT '字典interview_type: 1现场 2视频 3电话',
  location       VARCHAR(255) NULL COMMENT '现场地点',
  meeting_link   VARCHAR(512) NULL COMMENT '视频入会链接/码',
  sign_in_code   VARCHAR(32)  NULL COMMENT '现场签到码',
  status         TINYINT     NOT NULL DEFAULT 1 COMMENT '1待接受 2待面试 3进行中 4已完成 5已取消 6已爽约',
  checkin_time   DATETIME     NULL,
  remark         VARCHAR(500) NULL,
  created_by     BIGINT       NULL,
  created_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by     BIGINT       NULL,
  updated_time   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted        TINYINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_start_time (start_time, status),
  KEY idx_application (application_id, deleted)
) ENGINE=InnoDB COMMENT='面试';

CREATE TABLE interview_member (
  id            BIGINT      NOT NULL,
  interview_id  BIGINT      NOT NULL,
  user_id       BIGINT      NOT NULL COMMENT '面试官(后台用户)',
  role          VARCHAR(32) NOT NULL DEFAULT 'interviewer' COMMENT 'interviewer主面/lead主责HR',
  accept_status TINYINT     NOT NULL DEFAULT 0 COMMENT '0待接受 1已接受 2已拒绝',
  accept_time   DATETIME    NULL,
  created_by    BIGINT      NULL,
  created_time  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by    BIGINT      NULL,
  updated_time  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted       TINYINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_interview_user (interview_id, user_id, deleted),
  KEY idx_user (user_id, accept_status)
) ENGINE=InnoDB COMMENT='面试-面试官';

CREATE TABLE interview_evaluation (
  id             BIGINT        NOT NULL,
  interview_id   BIGINT        NOT NULL,
  user_id        BIGINT        NOT NULL COMMENT '评价人',
  scores         JSON          NOT NULL COMMENT '维度分: {"professional":4,"communication":5,...}',
  total_score    DECIMAL(4,1)  NOT NULL COMMENT '总分(平均分)',
  comment        VARCHAR(2000) NOT NULL COMMENT '综合评语',
  conclusion     TINYINT       NOT NULL COMMENT '字典eval_conclusion: 1推荐录用 2待定 3不推荐',
  submitted_time DATETIME      NOT NULL,
  created_by     BIGINT        NULL,
  created_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by     BIGINT        NULL,
  updated_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted        TINYINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_interview_user (interview_id, user_id, deleted)
) ENGINE=InnoDB COMMENT='面试评价';

CREATE TABLE offer (
  id             BIGINT        NOT NULL,
  application_id BIGINT        NOT NULL,
  candidate_id   BIGINT        NOT NULL,
  position_name  VARCHAR(128)  NOT NULL,
  dept_id        BIGINT        NULL,
  salary_min     DECIMAL(12,0) NULL,
  salary_max     DECIMAL(12,0) NULL,
  salary_note    VARCHAR(255)  NULL COMMENT '薪酬结构说明',
  probation_months INT         NULL,
  start_date     DATE          NULL COMMENT '报到时间',
  remark         VARCHAR(500)  NULL,
  status         TINYINT       NOT NULL DEFAULT 1 COMMENT '1草稿 2已发送 3已接受 4已拒绝 5已过期 6已撤回',
  sent_time      DATETIME      NULL,
  accepted_time  DATETIME      NULL,
  created_by     BIGINT        NULL,
  created_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by     BIGINT        NULL,
  updated_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted        TINYINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_application (application_id, deleted),
  KEY idx_status (status, created_time)
) ENGINE=InnoDB COMMENT='Offer';

-- ---------------- 题库/笔试域 ----------------

CREATE TABLE question_category (
  id           BIGINT      NOT NULL,
  parent_id    BIGINT      NOT NULL DEFAULT 0,
  name         VARCHAR(64) NOT NULL,
  sort         INT         NOT NULL DEFAULT 0,
  created_by   BIGINT      NULL,
  created_time DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by   BIGINT      NULL,
  updated_time DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted      TINYINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_parent (parent_id, deleted)
) ENGINE=InnoDB COMMENT='题目分类';

CREATE TABLE question (
  id           BIGINT        NOT NULL,
  category_id  BIGINT        NOT NULL,
  type         TINYINT       NOT NULL COMMENT '字典question_type: 1单选 2多选 3判断 4简答 5编程',
  stem         TEXT          NOT NULL COMMENT '题干',
  options      JSON          NULL COMMENT '选项,如 [{"key":"A","text":"..."}]',
  answer       TEXT          NULL COMMENT '正确答案(客观题)',
  analysis     TEXT          NULL COMMENT '解析',
  difficulty   TINYINT       NOT NULL DEFAULT 1 COMMENT '字典difficulty: 1简单 2中等 3困难',
  status       TINYINT       NOT NULL DEFAULT 1 COMMENT '1草稿 2已发布 3已废弃',
  created_by   BIGINT        NULL,
  created_time DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by   BIGINT        NULL,
  updated_time DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted      TINYINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_category_status (category_id, status, deleted),
  KEY idx_type (type, difficulty)
) ENGINE=InnoDB COMMENT='题目';

CREATE TABLE exam_paper (
  id             BIGINT      NOT NULL,
  name           VARCHAR(128) NOT NULL,
  position_id    BIGINT      NULL COMMENT '适用职位,可空=通用',
  mode           TINYINT     NOT NULL DEFAULT 1 COMMENT '1手动组卷 2随机组卷',
  rule_json      JSON        NULL COMMENT '随机规则: {"category":12,"difficulty":2,"count":10}',
  duration_min   INT         NOT NULL DEFAULT 60,
  total_score    DECIMAL(6,1) NOT NULL DEFAULT 100,
  allow_exit     TINYINT     NOT NULL DEFAULT 1 COMMENT '允许中途退出后重考: 0否 1是',
  max_attempts   INT         NOT NULL DEFAULT 1,
  status         TINYINT     NOT NULL DEFAULT 2 COMMENT '1草稿 2已发布',
  created_by     BIGINT      NULL,
  created_time   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by     BIGINT      NULL,
  updated_time   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted        TINYINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_status (status, deleted)
) ENGINE=InnoDB COMMENT='试卷';

CREATE TABLE paper_question (
  id           BIGINT NOT NULL,
  paper_id     BIGINT NOT NULL,
  question_id  BIGINT NOT NULL,
  score        DECIMAL(5,1) NOT NULL,
  seq          INT    NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_paper_question (paper_id, question_id),
  KEY idx_paper (paper_id, seq)
) ENGINE=InnoDB COMMENT='试卷-题目';

CREATE TABLE exam_record (
  id             BIGINT        NOT NULL,
  candidate_id   BIGINT        NOT NULL,
  paper_id       BIGINT        NOT NULL,
  attempt_no     INT           NOT NULL DEFAULT 1,
  status         TINYINT       NOT NULL DEFAULT 1 COMMENT '1进行中 2已交卷 3已评分',
  score          DECIMAL(6,1)  NULL,
  abnormal_flag  TINYINT       NOT NULL DEFAULT 0 COMMENT '切屏等异常标记',
  start_time     DATETIME      NOT NULL,
  submit_time    DATETIME      NULL,
  created_by     BIGINT        NULL,
  created_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by     BIGINT        NULL,
  updated_time   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted        TINYINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_candidate_paper (candidate_id, paper_id),
  KEY idx_status (status, submit_time)
) ENGINE=InnoDB COMMENT='考试记录';

CREATE TABLE exam_answer (
  id           BIGINT        NOT NULL,
  record_id    BIGINT        NOT NULL,
  question_id  BIGINT        NOT NULL,
  content      TEXT          NULL COMMENT '作答内容(选择题存选项key)',
  is_correct   TINYINT       NULL COMMENT '客观题: 1对 0错, 主观题NULL',
  manual_score DECIMAL(5,1)  NULL COMMENT '主观题人工分',
  created_by   BIGINT        NULL,
  created_time DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by   BIGINT        NULL,
  updated_time DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted      TINYINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_record_question (record_id, question_id, deleted)
) ENGINE=InnoDB COMMENT='考试作答';

-- ============================================================
-- 初始化数据
-- ============================================================

INSERT INTO sys_dept (id, name, parent_id, sort) VALUES
 (1, '总公司', 0, 1),
 (2, '技术部', 1, 1),
 (3, '人力资源部', 1, 2);

INSERT INTO sys_role (id, code, name, remark) VALUES
 (1, 'SUPER_ADMIN', '超级管理员', '系统内置'),
 (2, 'HR', '招聘专员', '系统内置'),
 (3, 'INTERVIEWER', '面试官', '系统内置');

INSERT INTO sys_permission (id, parent_id, name, code, type, path, sort) VALUES
 (1, 0, '工作台', 'dashboard', 1, '/dashboard', 1),
 (2, 0, '招聘管理', 'recruit', 1, NULL, 2),
 (3, 2, '职位管理', 'position:list', 1, '/positions', 1),
 (4, 3, '职位新增', 'position:add', 2, NULL, 1),
 (5, 3, '职位编辑', 'position:edit', 2, NULL, 2),
 (6, 3, '职位关闭', 'position:close', 2, NULL, 3),
 (7, 2, '候选人管理', 'candidate:list', 1, '/candidates', 2),
 (8, 2, '候选人查看明文', 'candidate:sensitive', 2, NULL, 1),
 (9, 2, '申请管理', 'application:list', 1, '/applications', 3),
 (10, 2, '申请状态流转', 'application:advance', 2, NULL, 1),
 (11, 0, '面试管理', 'interview', 1, NULL, 3),
 (12, 11, '面试安排', 'interview:list', 1, '/interviews', 1),
 (13, 12, '新建面试', 'interview:add', 2, NULL, 1),
 (14, 12, '面试改期/取消', 'interview:edit', 2, NULL, 2),
 (15, 11, '我的面试', 'interview:my', 1, '/my-interviews', 2),
 (16, 15, '提交评价', 'interview:evaluate', 2, NULL, 1),
 (17, 0, 'Offer管理', 'offer:list', 1, '/offers', 4),
 (18, 17, '创建Offer', 'offer:add', 2, NULL, 1),
 (19, 17, '撤回Offer', 'offer:revoke', 2, NULL, 2),
 (20, 0, '题库与笔试', 'exam', 1, NULL, 5),
 (21, 20, '题库管理', 'question:list', 1, '/questions', 1),
 (22, 20, '组卷管理', 'exam-paper:list', 1, '/exam-papers', 2),
 (23, 20, '成绩管理', 'exam-record:list', 1, '/exam-records', 3),
 (24, 0, '统计报表', 'report:list', 1, '/reports', 6),
 (25, 0, '系统管理', 'system', 1, NULL, 7),
 (26, 25, '用户管理', 'system:user:list', 1, '/system/users', 1),
 (27, 25, '角色权限', 'system:role:list', 1, '/system/roles', 2),
 (28, 25, '字典管理', 'system:dict:list', 1, '/system/dicts', 3),
 (29, 25, '操作日志', 'system:log:list', 1, '/system/logs', 4);

INSERT INTO sys_role_permission (role_id, permission_id)
SELECT 1, id FROM sys_permission;

INSERT INTO sys_role_permission (role_id, permission_id) VALUES
 (2, 1),(2,2),(2,3),(2,4),(2,5),(2,6),(2,7),(2,8),(2,9),(2,10),(2,12),(2,13),(2,14),(2,17),(2,18),(2,19),(2,20),(2,21),(2,22),(2,23),(2,24),
 (3, 1),(3,15),(3,16);

INSERT INTO sys_dict_type (id, type_code, name) VALUES
 (1, 'gender', '性别'),
 (2, 'education', '学历'),
 (3, 'interview_type', '面试方式'),
 (4, 'round_type', '面试轮次类型'),
 (5, 'reject_reason', '淘汰原因'),
 (6, 'eval_conclusion', '评价结论'),
 (7, 'question_type', '题型'),
 (8, 'question_difficulty', '题目难度'),
 (9, 'candidate_source', '候选人来源'),
 (10, 'notify_type', '通知类型');

INSERT INTO sys_dict_data (id, type_code, label, value, sort) VALUES
 (1, 'gender', '男', '1', 1), (2, 'gender', '女', '2', 2),
 (101, 'education', '专科', 'college', 1), (102, 'education', '本科', 'bachelor', 2),
 (103, 'education', '硕士', 'master', 3), (104, 'education', '博士', 'phd', 4),
 (201, 'interview_type', '现场', '1', 1), (202, 'interview_type', '视频', '2', 2), (203, 'interview_type', '电话', '3', 3),
 (301, 'round_type', '电话初筛', 'phone', 1), (302, 'round_type', '一面', 'first', 2),
 (303, 'round_type', '二面', 'second', 3), (304, 'round_type', '终面', 'final', 4),
 (401, 'reject_reason', '能力不匹配', 'skill_mismatch', 1), (402, 'reject_reason', '经验不足', 'no_experience', 2),
 (403, 'reject_reason', '薪资期望不符', 'salary_gap', 3), (404, 'reject_reason', '其他', 'other', 4),
 (501, 'eval_conclusion', '推荐录用', '1', 1), (502, 'eval_conclusion', '待定', '2', 2), (503, 'eval_conclusion', '不推荐', '3', 3),
 (601, 'question_type', '单选', '1', 1), (602, 'question_type', '多选', '2', 2),
 (603, 'question_type', '判断', '3', 3), (604, 'question_type', '简答', '4', 4), (605, 'question_type', '编程', '5', 5),
 (701, 'question_difficulty', '简单', '1', 1), (702, 'question_difficulty', '中等', '2', 2), (703, 'question_difficulty', '困难', '3', 3),
 (801, 'candidate_source', '官网投递', 'website', 1), (802, 'candidate_source', '内推', 'referral', 2),
 (803, 'candidate_source', '招聘网站', 'job_site', 3), (804, 'candidate_source', '线下录入', 'offline', 4),
 (901, 'notify_type', '面试邀请', 'interview_invite', 1), (902, 'notify_type', '面试改期', 'interview_reschedule', 2),
 (903, 'notify_type', '面试提醒', 'interview_reminder', 3), (904, 'notify_type', 'Offer', 'offer', 4),
 (905, 'notify_type', '结果通知', 'result', 5), (906, 'notify_type', '催办', 'urge', 6);
