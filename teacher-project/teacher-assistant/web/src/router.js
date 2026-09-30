import { createRouter, createWebHashHistory } from 'vue-router';
import ClassManage from './views/ClassManage.vue';
import StudentManage from './views/StudentManage.vue';
import Roster from './views/Roster.vue';
import Lottery from './views/Lottery.vue';
import ScoreManage from './views/ScoreManage.vue';
import ScoreAnalysis from './views/ScoreAnalysis.vue';
import Ranking from './views/Ranking.vue';
import Seats from './views/Seats.vue';

export default createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: '/', redirect: '/classes' },
    { path: '/classes', component: ClassManage },
    { path: '/students', component: StudentManage },
    { path: '/roster', component: Roster },
    { path: '/lottery', component: Lottery },
    { path: '/scores', component: ScoreManage },
    { path: '/analysis', component: ScoreAnalysis },
    { path: '/ranking', component: Ranking },
    { path: '/seats', component: Seats },
  ],
});
