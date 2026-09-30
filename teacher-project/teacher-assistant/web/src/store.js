import { reactive } from 'vue';
import { api } from './api';

const CLASS_KEY = 'ta_current_class_id';

export const store = reactive({
  classes: [],
  currentClassId: localStorage.getItem(CLASS_KEY) || null,

  get currentClass() {
    return this.classes.find((c) => c.id === this.currentClassId) || null;
  },

  async loadClasses() {
    this.classes = await api.get('/classes');
    const exists = this.classes.some((c) => c.id === this.currentClassId);
    if (!exists) this.currentClassId = this.classes.length ? this.classes[0].id : null;
    this.persist();
  },

  setCurrentClass(id) {
    this.currentClassId = id;
    this.persist();
  },

  persist() {
    if (this.currentClassId) localStorage.setItem(CLASS_KEY, this.currentClassId);
    else localStorage.removeItem(CLASS_KEY);
  },
});
