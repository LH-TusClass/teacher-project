<template>
  <el-container class="app-shell">
    <el-aside width="210px" class="sidebar">
      <div class="logo">🎒 班级助手</div>
      <el-menu :default-active="route.path" router text-color="#bfcbd9" active-text-color="#ffd04b">
        <el-menu-item index="/classes">🏫 班级管理</el-menu-item>
        <el-menu-item index="/students">👥 学生管理</el-menu-item>
        <el-menu-item index="/roster">📋 班级花名册</el-menu-item>
        <el-menu-item index="/lottery">🎰 课堂抽奖</el-menu-item>
        <el-menu-item index="/scores">📝 成绩管理</el-menu-item>
        <el-menu-item index="/analysis">📊 成绩分析</el-menu-item>
        <el-menu-item index="/ranking">🏆 成绩排名</el-menu-item>
        <el-menu-item index="/seats">🪑 座位编排</el-menu-item>
      </el-menu>
    </el-aside>
    <el-container>
      <el-header class="topbar">
        <div class="title">教师学生管理平台</div>
        <div class="class-picker">
          <span>当前班级：</span>
          <el-select
            :model-value="store.currentClassId"
            size="large"
            style="width: 200px"
            placeholder="请选择班级"
            @update:model-value="store.setCurrentClass"
          >
            <el-option v-for="c in store.classes" :key="c.id" :label="`${c.name}（${c.studentCount}人）`" :value="c.id" />
          </el-select>
        </div>
      </el-header>
      <el-main class="main">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup>
import { onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { store } from './store';

const route = useRoute();
onMounted(() => store.loadClasses());
</script>
