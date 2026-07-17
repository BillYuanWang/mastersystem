const PREFS_KEY = "jiamei_master_schedule_prefs_v1";
const FILE_DB_NAME = "jiamei_master_schedule_files_v1";
const FILE_STORE_NAME = "handles";
const CSV_HANDLE_KEY = "coursesCsv";
const DEFAULT_ZOOM = 100;
const ZOOM_MIN = 70;
const ZOOM_MAX = 180;
const ZOOM_STEP = 5;
const DEFAULT_APPEARANCE = "system";
const SCHEDULE_DEFAULT_START = 9 * 60 + 30;
const SCHEDULE_DEFAULT_END = 20 * 60 + 30;
const SCHEDULE_RANGE_STEP = 30;

const DAYS = [
  { id: "mon", label: "周一", order: 1 },
  { id: "tue", label: "周二", order: 2 },
  { id: "wed", label: "周三", order: 3 },
  { id: "thu", label: "周四", order: 4 },
  { id: "fri", label: "周五", order: 5 },
  { id: "sat", label: "周六", order: 6 },
  { id: "sun", label: "周日", order: 7 },
];

const DAY_INDEX = {
  sun: 0,
  mon: 1,
  tue: 2,
  wed: 3,
  thu: 4,
  fri: 5,
  sat: 6,
};

const ROOMS = [
  { id: "large", label: "大教室" },
  { id: "small", label: "小教室" },
];

const CLASS_MODES = [
  { id: "group", label: "组课" },
  { id: "private", label: "私课" },
];

const ENROLLMENT_TYPES = [
  { id: "term", label: "按期" },
  { id: "passes", label: "按N次" },
];

const CATEGORY_PALETTE = [
  "#1b8a84",
  "#c75643",
  "#426aa7",
  "#d49a23",
  "#5c8f43",
  "#b75f7a",
  "#7c674b",
  "#4e7b91",
];

const CSV_COLUMNS = [
  { key: "id", label: "课程ID", aliases: ["id", "ID", "courseId"] },
  { key: "name", label: "课程名称", aliases: ["name", "课程", "courseName"] },
  { key: "category", label: "课程类型", aliases: ["category", "类型", "courseType"] },
  { key: "classMode", label: "组课私课", aliases: ["classMode", "属性", "组课/私课", "课程属性"] },
  { key: "teacher", label: "老师", aliases: ["teacher", "教师"] },
  { key: "age", label: "年龄段", aliases: ["age", "年龄"] },
  { key: "day", label: "星期", aliases: ["day", "weekday"] },
  { key: "room", label: "教室", aliases: ["room", "classroom"] },
  { key: "start", label: "开始时间", aliases: ["start", "startTime"] },
  { key: "end", label: "结束时间", aliases: ["end", "endTime"] },
  { key: "startDate", label: "起始周", aliases: ["startDate", "起始日期", "开始日期", "startWeek"] },
  { key: "endDate", label: "结束周", aliases: ["endDate", "结束日期", "endWeek"] },
  { key: "excludedDates", label: "停课日期", aliases: ["excludedDates", "排除日期", "休息日期", "不上课日期"] },
  { key: "singlePrice", label: "单期价格", aliases: ["singlePrice", "单期报名价格", "单期报名的价格", "单次价格"] },
  { key: "termPrice", label: "按期价格", aliases: ["termPrice", "按期报名价格", "按期报名的价格", "整期价格"] },
  { key: "enrollments", label: "报名学生", aliases: ["enrollments", "students", "学生", "报名孩子"] },
  { key: "notes", label: "备注", aliases: ["notes", "note", "说明"] },
  { key: "createdAt", label: "创建时间", aliases: ["createdAt"] },
  { key: "updatedAt", label: "更新时间", aliases: ["updatedAt"] },
];

const state = {
  courses: [],
  storage: {
    connected: false,
    handle: null,
    backend: "",
    fileName: "",
    dataPath: "",
    lastSavedAt: null,
    status: "idle",
    message: "",
  },
  activeView: "schedule",
  schedule: {
    weekMode: "weekdays",
    roomMode: "both",
    age: "all",
    category: "all",
    teacher: "all",
    zoom: loadScheduleZoom(),
  },
  table: {
    search: "",
    day: "all",
    room: "all",
    age: "all",
    category: "all",
    teacher: "all",
    sortKey: "dayTime",
    sortDir: "asc",
  },
  students: {
    search: "",
    enrollmentType: "all",
  },
  enrollment: {
    search: "",
    enrollmentType: "all",
  },
  appearance: loadAppearancePreference(),
};

const els = {};
let formExcludedDates = new Set();
let nativeRequestId = 0;
const nativeRequests = new Map();

window.masterDanceNative = {
  receive(response) {
    const request = nativeRequests.get(response?.id);
    if (!request) return;
    nativeRequests.delete(response.id);
    if (response.ok) {
      request.resolve(response);
    } else {
      request.reject(new Error(response.error || "macOS app storage error"));
    }
  },
};

document.addEventListener("DOMContentLoaded", async () => {
  cacheElements();
  document.body.dataset.activeView = state.activeView;
  hydrateStaticSelects();
  bindEvents();
  applyAppearance();
  renderAll();
  await initializeCoursesData();
});

function cacheElements() {
  els.recordCount = document.querySelector("#recordCount");
  els.appearanceSelect = document.querySelector("#appearanceSelect");
  els.tabs = Array.from(document.querySelectorAll(".tab"));
  els.views = {
    schedule: document.querySelector("#scheduleView"),
    manage: document.querySelector("#manageView"),
    students: document.querySelector("#studentsView"),
    enrollment: document.querySelector("#enrollmentView"),
  };
  els.printBtn = document.querySelector("#printBtn");
  els.addCourseTop = document.querySelector("#addCourseTop");
  els.addCourseManage = document.querySelector("#addCourseManage");
  els.scheduleSubtitle = document.querySelector("#scheduleSubtitle");
  els.printMeta = document.querySelector("#printMeta");
  els.scheduleBoard = document.querySelector("#scheduleBoard");
  els.scheduleZoom = document.querySelector("#scheduleZoom");
  els.scheduleZoomValue = document.querySelector("#scheduleZoomValue");
  els.scheduleZoomReset = document.querySelector("#scheduleZoomReset");
  els.weekModeGroup = document.querySelector("#weekModeGroup");
  els.roomModeGroup = document.querySelector("#roomModeGroup");
  els.scheduleAgeFilter = document.querySelector("#scheduleAgeFilter");
  els.scheduleCategoryFilter = document.querySelector("#scheduleCategoryFilter");
  els.scheduleTeacherFilter = document.querySelector("#scheduleTeacherFilter");
  els.tableSearch = document.querySelector("#tableSearch");
  els.tableDayFilter = document.querySelector("#tableDayFilter");
  els.tableRoomFilter = document.querySelector("#tableRoomFilter");
  els.tableAgeFilter = document.querySelector("#tableAgeFilter");
  els.tableCategoryFilter = document.querySelector("#tableCategoryFilter");
  els.tableTeacherFilter = document.querySelector("#tableTeacherFilter");
  els.courseTableBody = document.querySelector("#courseTableBody");
  els.studentsSubtitle = document.querySelector("#studentsSubtitle");
  els.studentSearch = document.querySelector("#studentSearch");
  els.studentEnrollmentFilter = document.querySelector("#studentEnrollmentFilter");
  els.studentBoard = document.querySelector("#studentBoard");
  els.enrollmentSubtitle = document.querySelector("#enrollmentSubtitle");
  els.enrollmentSearch = document.querySelector("#enrollmentSearch");
  els.enrollmentTypeFilter = document.querySelector("#enrollmentTypeFilter");
  els.enrollmentBoard = document.querySelector("#enrollmentBoard");
  els.storageStatus = document.querySelector("#storageStatus");
  els.createCsvBtn = document.querySelector("#createCsvBtn");
  els.connectCsvBtn = document.querySelector("#connectCsvBtn");
  els.exportBtn = document.querySelector("#exportBtn");
  els.importFile = document.querySelector("#importFile");
  els.clearCoursesBtn = document.querySelector("#clearCoursesBtn");
  els.courseDialog = document.querySelector("#courseDialog");
  els.courseForm = document.querySelector("#courseForm");
  els.dialogTitle = document.querySelector("#dialogTitle");
  els.dialogSubtitle = document.querySelector("#dialogSubtitle");
  els.closeDialogBtn = document.querySelector("#closeDialogBtn");
  els.cancelDialogBtn = document.querySelector("#cancelDialogBtn");
  els.courseId = document.querySelector("#courseId");
  els.courseName = document.querySelector("#courseName");
  els.courseCategory = document.querySelector("#courseCategory");
  els.courseClassMode = document.querySelector("#courseClassMode");
  els.courseTeacher = document.querySelector("#courseTeacher");
  els.courseAge = document.querySelector("#courseAge");
  els.courseDay = document.querySelector("#courseDay");
  els.courseRoom = document.querySelector("#courseRoom");
  els.courseStartDate = document.querySelector("#courseStartDate");
  els.courseEndDate = document.querySelector("#courseEndDate");
  els.courseStart = document.querySelector("#courseStart");
  els.courseEnd = document.querySelector("#courseEnd");
  els.courseSinglePrice = document.querySelector("#courseSinglePrice");
  els.courseTermPrice = document.querySelector("#courseTermPrice");
  els.sessionCount = document.querySelector("#sessionCount");
  els.sessionList = document.querySelector("#sessionList");
  els.addEnrollmentBtn = document.querySelector("#addEnrollmentBtn");
  els.enrollmentList = document.querySelector("#enrollmentList");
  els.courseNotes = document.querySelector("#courseNotes");
  els.conflictBox = document.querySelector("#conflictBox");
  els.readonlyCourseDialog = document.querySelector("#readonlyCourseDialog");
  els.readonlyCourseTitle = document.querySelector("#readonlyCourseTitle");
  els.readonlyCourseSubtitle = document.querySelector("#readonlyCourseSubtitle");
  els.readonlyCourseBody = document.querySelector("#readonlyCourseBody");
  els.closeReadonlyDialogBtn = document.querySelector("#closeReadonlyDialogBtn");
  els.readonlyDialogDoneBtn = document.querySelector("#readonlyDialogDoneBtn");
  els.studentEnrollDialog = document.querySelector("#studentEnrollDialog");
  els.studentEnrollForm = document.querySelector("#studentEnrollForm");
  els.studentEnrollTitle = document.querySelector("#studentEnrollTitle");
  els.studentEnrollSubtitle = document.querySelector("#studentEnrollSubtitle");
  els.studentEnrollName = document.querySelector("#studentEnrollName");
  els.studentEnrollCourse = document.querySelector("#studentEnrollCourse");
  els.studentEnrollType = document.querySelector("#studentEnrollType");
  els.closeStudentEnrollDialogBtn = document.querySelector("#closeStudentEnrollDialogBtn");
  els.cancelStudentEnrollDialogBtn = document.querySelector("#cancelStudentEnrollDialogBtn");
  els.categoryOptions = document.querySelector("#categoryOptions");
  els.teacherOptions = document.querySelector("#teacherOptions");
  els.ageOptions = document.querySelector("#ageOptions");
  els.studentOptions = document.querySelector("#studentOptions");
}

function hydrateStaticSelects() {
  DAYS.forEach((day) => {
    els.courseDay.append(new Option(day.label, day.id));
  });
  ROOMS.forEach((room) => {
    els.courseRoom.append(new Option(room.label, room.id));
  });
  CLASS_MODES.forEach((mode) => {
    els.courseClassMode.append(new Option(mode.label, mode.id));
  });
}

function bindEvents() {
  els.tabs.forEach((tab) => {
    tab.addEventListener("click", () => switchView(tab.dataset.view));
  });

  els.appearanceSelect.addEventListener("change", () => {
    state.appearance = normalizeAppearance(els.appearanceSelect.value);
    persistSchedulePrefs();
    applyAppearance();
  });

  const themeQuery = window.matchMedia?.("(prefers-color-scheme: dark)");
  const syncSystemAppearance = () => {
    if (state.appearance === "system") applyAppearance();
  };
  themeQuery?.addEventListener?.("change", syncSystemAppearance);
  themeQuery?.addListener?.(syncSystemAppearance);
  window.addEventListener("focus", syncSystemAppearance);
  document.addEventListener("visibilitychange", syncSystemAppearance);

  els.weekModeGroup.addEventListener("click", (event) => {
    const button = event.target.closest("button[data-week-mode]");
    if (!button) return;
    state.schedule.weekMode = button.dataset.weekMode;
    renderAll();
  });

  els.roomModeGroup.addEventListener("click", (event) => {
    const button = event.target.closest("button[data-room-mode]");
    if (!button) return;
    state.schedule.roomMode = button.dataset.roomMode;
    renderAll();
  });

  els.scheduleZoom.addEventListener("input", () => {
    setScheduleZoom(Number(els.scheduleZoom.value));
  });

  els.scheduleZoomReset.addEventListener("click", () => {
    setScheduleZoom(DEFAULT_ZOOM);
  });

  els.scheduleBoard.addEventListener("wheel", (event) => {
    if (!event.ctrlKey && !event.metaKey) return;
    event.preventDefault();
    const direction = event.deltaY < 0 ? 1 : -1;
    setScheduleZoom(state.schedule.zoom + direction * ZOOM_STEP);
  }, { passive: false });

  [
    [els.scheduleAgeFilter, state.schedule, "age"],
    [els.scheduleCategoryFilter, state.schedule, "category"],
    [els.scheduleTeacherFilter, state.schedule, "teacher"],
    [els.tableDayFilter, state.table, "day"],
    [els.tableRoomFilter, state.table, "room"],
    [els.tableAgeFilter, state.table, "age"],
    [els.tableCategoryFilter, state.table, "category"],
    [els.tableTeacherFilter, state.table, "teacher"],
  ].forEach(([element, target, key]) => {
    element.addEventListener("change", () => {
      target[key] = element.value;
      renderAll();
    });
  });

  els.tableSearch.addEventListener("input", () => {
    state.table.search = els.tableSearch.value.trim();
    renderTable();
  });

  els.studentSearch.addEventListener("input", () => {
    state.students.search = els.studentSearch.value.trim();
    renderStudents();
  });

  els.studentEnrollmentFilter.addEventListener("change", () => {
    state.students.enrollmentType = els.studentEnrollmentFilter.value;
    renderStudents();
  });

  els.enrollmentSearch.addEventListener("input", () => {
    state.enrollment.search = els.enrollmentSearch.value.trim();
    renderEnrollment();
  });

  els.enrollmentTypeFilter.addEventListener("change", () => {
    state.enrollment.enrollmentType = els.enrollmentTypeFilter.value;
    renderEnrollment();
  });

  document.querySelector(".course-table thead").addEventListener("click", (event) => {
    const button = event.target.closest("button[data-sort]");
    if (!button) return;
    const sortKey = button.dataset.sort;
    if (state.table.sortKey === sortKey) {
      state.table.sortDir = state.table.sortDir === "asc" ? "desc" : "asc";
    } else {
      state.table.sortKey = sortKey;
      state.table.sortDir = "asc";
    }
    renderTable();
  });

  els.printBtn.addEventListener("click", () => window.print());
  els.addCourseTop.addEventListener("click", () => openCourseDialog());
  els.addCourseManage.addEventListener("click", () => openCourseDialog());
  els.closeDialogBtn.addEventListener("click", closeCourseDialog);
  els.cancelDialogBtn.addEventListener("click", closeCourseDialog);
  els.closeReadonlyDialogBtn.addEventListener("click", closeReadonlyCourseDialog);
  els.readonlyDialogDoneBtn.addEventListener("click", closeReadonlyCourseDialog);
  els.closeStudentEnrollDialogBtn.addEventListener("click", closeStudentEnrollDialog);
  els.cancelStudentEnrollDialogBtn.addEventListener("click", closeStudentEnrollDialog);
  els.studentEnrollForm.addEventListener("submit", addCourseToStudentFromDialog);
  els.courseForm.addEventListener("submit", saveCourseFromForm);
  els.addEnrollmentBtn.addEventListener("click", () => addEnrollmentRow());
  els.enrollmentList.addEventListener("click", (event) => {
    const button = event.target.closest(".remove-enrollment");
    if (!button) return;
    button.closest(".enrollment-row")?.remove();
    ensureEnrollmentPlaceholder();
  });
  els.sessionList.addEventListener("click", (event) => {
    const button = event.target.closest(".remove-session");
    if (!button) return;
    const date = button.dataset.date;
    if (date) {
      formExcludedDates.add(date);
      renderSessionPreview();
    }
  });
  els.createCsvBtn.addEventListener("click", createCsvFile);
  els.connectCsvBtn.addEventListener("click", connectCsvFile);
  els.exportBtn.addEventListener("click", exportCourses);
  els.importFile.addEventListener("change", importCourses);
  els.clearCoursesBtn.addEventListener("click", clearCourses);

  [els.courseDay, els.courseRoom, els.courseStart, els.courseEnd].forEach((element) => {
    element.addEventListener("input", renderConflictNotice);
    element.addEventListener("change", renderConflictNotice);
  });

  [els.courseDay, els.courseStartDate, els.courseEndDate].forEach((element) => {
    element.addEventListener("input", renderSessionPreview);
    element.addEventListener("change", renderSessionPreview);
  });
}

function switchView(view) {
  state.activeView = view;
  document.body.dataset.activeView = view;
  els.tabs.forEach((tab) => tab.classList.toggle("is-active", tab.dataset.view === view));
  Object.entries(els.views).forEach(([key, element]) => {
    element.classList.toggle("is-active", key === view);
  });
}

function loadScheduleZoom() {
  try {
    const raw = localStorage.getItem(PREFS_KEY);
    if (!raw) return DEFAULT_ZOOM;
    const parsed = JSON.parse(raw);
    return clampZoom(parsed.zoom);
  } catch (error) {
    console.warn("课程表偏好读取失败", error);
    return DEFAULT_ZOOM;
  }
}

function loadAppearancePreference() {
  try {
    const raw = localStorage.getItem(PREFS_KEY);
    if (!raw) return DEFAULT_APPEARANCE;
    return normalizeAppearance(JSON.parse(raw).appearance);
  } catch (error) {
    console.warn("外观偏好读取失败", error);
    return DEFAULT_APPEARANCE;
  }
}

function persistSchedulePrefs() {
  localStorage.setItem(PREFS_KEY, JSON.stringify({
    zoom: state.schedule.zoom,
    appearance: state.appearance,
  }));
}

function normalizeAppearance(value) {
  return ["system", "light", "dark"].includes(value) ? value : DEFAULT_APPEARANCE;
}

function applyAppearance() {
  const appearance = normalizeAppearance(state.appearance);
  const prefersDark = window.matchMedia?.("(prefers-color-scheme: dark)").matches;
  const resolved = appearance === "dark" || (appearance === "system" && prefersDark) ? "dark" : "light";
  document.documentElement.dataset.theme = resolved;
  if (els.appearanceSelect) els.appearanceSelect.value = appearance;
}

function canUseCsvFileStorage() {
  return typeof window.showOpenFilePicker === "function";
}

function canCreateCsvFileStorage() {
  return typeof window.showSaveFilePicker === "function";
}

function canUseLocalServerStorage() {
  return window.location.protocol === "http:"
    && ["127.0.0.1", "localhost", "[::1]"].includes(window.location.hostname);
}

function canUseNativeStorage() {
  return Boolean(window.webkit?.messageHandlers?.masterDance?.postMessage);
}

function requestNativeStorage(action, payload = {}) {
  return new Promise((resolve, reject) => {
    const id = `native-${Date.now()}-${++nativeRequestId}`;
    nativeRequests.set(id, { resolve, reject });
    const timeout = window.setTimeout(() => {
      if (!nativeRequests.has(id)) return;
      nativeRequests.delete(id);
      reject(new Error("macOS app did not respond to the storage request."));
    }, 10000);

    nativeRequests.set(id, {
      resolve(value) {
        window.clearTimeout(timeout);
        resolve(value);
      },
      reject(error) {
        window.clearTimeout(timeout);
        reject(error);
      },
    });

    try {
      window.webkit.messageHandlers.masterDance.postMessage({ id, action, ...payload });
    } catch (error) {
      nativeRequests.delete(id);
      window.clearTimeout(timeout);
      reject(error);
    }
  });
}

async function initializeCoursesData() {
  const loadedAdjacentCsv = await loadAdjacentCoursesCsv();
  await restoreSavedCsvHandle({ quietWhenMissing: loadedAdjacentCsv });
}

async function loadAdjacentCoursesCsv() {
  if (canUseNativeStorage()) {
    try {
      const result = await requestNativeStorage("loadCsv");
      const text = result.csv || "";
      state.courses = text.trim() ? parseCoursesCsv(text) : [];
      state.storage.connected = true;
      state.storage.handle = null;
      state.storage.backend = "native";
      state.storage.fileName = result.fileName || "courses.csv";
      state.storage.dataPath = result.path || "";
      state.storage.status = "connected";
      state.storage.message = "";
      renderAll();
      return true;
    } catch (error) {
      console.error("macOS app 读取 courses.csv 失败。", error);
      state.storage.status = "error";
      state.storage.message = "macOS app 读取 CSV 失败，请检查 Data 文件夹。";
      renderAll();
      return false;
    }
  }

  try {
    const response = await fetch("./courses.csv", { cache: "no-store" });
    if (!response.ok) return false;
    const text = await response.text();
    const serverStorage = canUseLocalServerStorage();
    state.courses = text.trim() ? parseCoursesCsv(text) : [];
    state.storage.connected = serverStorage;
    state.storage.handle = null;
    state.storage.backend = serverStorage ? "server" : "readonly";
    state.storage.fileName = "courses.csv";
    state.storage.status = serverStorage ? "connected" : "readonly";
    state.storage.message = serverStorage ? "" : "已自动读取 courses.csv；修改时会请求一次保存权限。";
    renderAll();
    return true;
  } catch (error) {
    console.warn("浏览器没有允许自动读取同目录 courses.csv。", error);
    return false;
  }
}

async function restoreSavedCsvHandle(options = {}) {
  if (canUseNativeStorage()) return;
  const quietWhenMissing = Boolean(options.quietWhenMissing);
  if (!canUseCsvFileStorage()) {
    state.storage.status = quietWhenMissing ? "readonly" : "error";
    state.storage.message = quietWhenMissing
      ? "已自动显示 courses.csv；当前浏览器不支持直接写入本地 CSV。"
      : "直接打开 index.html 时，浏览器不能自动读取 courses.csv。请双击「打开 Master Dance.command」进入。";
    renderAll();
    return;
  }

  const handle = await getSavedCsvHandle();
  if (!handle) {
    if (!quietWhenMissing) {
      state.storage.status = "warning";
      state.storage.message = "直接打开 index.html 时，浏览器不能自动读取 courses.csv。请双击「打开 Master Dance.command」进入，或在 CSV 备用里重新授权。";
    }
    renderAll();
    return;
  }

  state.storage.handle = handle;
  state.storage.fileName = handle.name || "courses.csv";
  const readPermission = await queryCsvPermission(handle, "read");
  if (readPermission === "granted") {
    await loadCoursesFromCsvHandle(handle, { requestWrite: false });
  }

  const writePermission = await queryCsvPermission(handle, "readwrite");
  if (writePermission !== "granted") {
    state.storage.connected = false;
    state.storage.backend = "";
    state.storage.status = readPermission === "granted" || quietWhenMissing ? "readonly" : "warning";
    state.storage.message = `已记住 ${state.storage.fileName}，首次修改时会请求写入权限。`;
    renderStorageStatus();
    return;
  }

  await loadCoursesFromCsvHandle(handle);
}

async function createCsvFile() {
  if (!canCreateCsvFileStorage()) {
    alert("当前浏览器不支持直接写本地 CSV。请使用 Chrome 或 Edge 打开这个页面。");
    return;
  }

  try {
    const handle = await window.showSaveFilePicker({
      suggestedName: "courses.csv",
      types: [
        {
          description: "CSV 课程数据",
          accept: { "text/csv": [".csv"] },
        },
      ],
    });
    state.storage.handle = handle;
    state.storage.fileName = handle.name || "courses.csv";
    state.storage.connected = true;
    state.storage.backend = "file";
    state.storage.status = "connected";
    await saveCsvHandle(handle);
    await writeCoursesToCsv();
    renderAll();
  } catch (error) {
    if (error?.name !== "AbortError") {
      console.error(error);
      alert("新建 CSV 失败，请确认浏览器允许文件写入。");
    }
  }
}

async function connectCsvFile(options = {}) {
  const silent = Boolean(options.silent);
  if (!canUseCsvFileStorage()) {
    if (!silent) alert("当前浏览器不支持直接写本地 CSV。请使用 Chrome 或 Edge 打开这个页面。");
    return false;
  }

  try {
    const [handle] = await window.showOpenFilePicker({
      multiple: false,
      types: [
        {
          description: "CSV 课程数据",
          accept: { "text/csv": [".csv"] },
        },
      ],
    });
    if (!handle) return false;
    const granted = await verifyCsvPermission(handle);
    if (!granted) {
      if (!silent) alert("没有获得 CSV 文件读写权限。");
      return false;
    }
    await saveCsvHandle(handle);
    await loadCoursesFromCsvHandle(handle);
    return true;
  } catch (error) {
    if (error?.name !== "AbortError") {
      console.error(error);
      if (!silent) alert("连接 CSV 失败，请确认文件格式正确。");
    }
    return false;
  }
}

async function loadCoursesFromCsvHandle(handle, options = {}) {
  const requestWrite = options.requestWrite !== false;
  try {
    const granted = requestWrite
      ? await verifyCsvPermission(handle, "readwrite")
      : (await queryCsvPermission(handle, "read")) === "granted";
    if (!granted) {
      state.storage.connected = false;
      state.storage.status = "warning";
      state.storage.message = requestWrite ? "没有 CSV 文件读写权限。" : "没有 CSV 文件读取权限。";
      renderStorageStatus();
      return false;
    }

    const file = await handle.getFile();
    const text = await file.text();
    state.courses = text.trim() ? parseCoursesCsv(text) : [];
    state.storage.handle = handle;
    state.storage.fileName = handle.name || file.name || "courses.csv";
    state.storage.connected = requestWrite;
    state.storage.backend = requestWrite ? "file" : "readonly";
    state.storage.status = requestWrite ? "connected" : "readonly";
    state.storage.message = requestWrite ? "" : `已读取 ${state.storage.fileName}；首次修改时会请求写入权限。`;
    await saveCsvHandle(handle);
    if (requestWrite && !text.trim()) await writeCoursesToCsv();
    renderAll();
    return true;
  } catch (error) {
    console.error(error);
    state.storage.connected = false;
    state.storage.status = "error";
    state.storage.message = "读取 CSV 失败，请检查文件内容。";
    renderStorageStatus();
    return false;
  }
}

async function commitCourses(nextCourses) {
  const previousCourses = state.courses;
  const normalized = nextCourses.map(normalizeCourse).filter(Boolean);
  if (!(await ensureWritableCsv())) return false;

  state.courses = normalized;
  try {
    await writeCoursesToCsv();
    renderAll();
    return true;
  } catch (error) {
    console.error(error);
    state.courses = previousCourses;
    state.storage.status = "error";
    state.storage.message = "写入 CSV 失败，已保留修改前数据。";
    renderAll();
    alert("写入 CSV 失败，请确认 Dropbox 文件没有被其它程序锁定。");
    return false;
  }
}

async function ensureWritableCsv() {
  if (canUseNativeStorage()) return true;
  if (canUseLocalServerStorage()) return true;
  if (!canUseCsvFileStorage()) {
    alert("直接打开 index.html 无法自动写 CSV。请双击「打开 Master Dance.command」进入。");
    return false;
  }
  if (!state.storage.handle) {
    state.storage.status = "warning";
    state.storage.message = "需要授权 Dropbox 文件夹里的 courses.csv 才能保存修改。";
    renderStorageStatus();
    const connected = await connectCsvFile({ silent: true });
    if (!connected) {
      alert("还没有 CSV 保存权限。请在弹出的窗口里选择 Dropbox 文件夹里的 courses.csv。");
      switchView("manage");
      return false;
    }
    return true;
  }
  const granted = await verifyCsvPermission(state.storage.handle, "readwrite");
  if (!granted) {
    state.storage.connected = false;
    state.storage.status = "warning";
    state.storage.message = "CSV 文件需要重新授权，请在 CSV 备用里点“重新授权”。";
    renderStorageStatus();
    alert("没有 CSV 文件写入权限，请重新授权 CSV。");
    return false;
  }
  state.storage.connected = true;
  state.storage.backend = "file";
  state.storage.status = "connected";
  state.storage.message = "";
  return true;
}

async function writeCoursesToCsv() {
  if (canUseNativeStorage()) {
    await writeCoursesToNativeApp();
    return;
  }
  if (canUseLocalServerStorage()) {
    await writeCoursesToLocalServer();
    return;
  }
  if (!state.storage.handle) throw new Error("No CSV handle connected");
  const writable = await state.storage.handle.createWritable();
  await writable.write(coursesToCsv(state.courses));
  await writable.close();
  state.storage.connected = true;
  state.storage.status = "connected";
  state.storage.message = "";
  state.storage.lastSavedAt = new Date();
  renderStorageStatus();
}

async function writeCoursesToNativeApp() {
  const result = await requestNativeStorage("saveCsv", { csv: coursesToCsv(state.courses) });
  state.storage.connected = true;
  state.storage.backend = "native";
  state.storage.fileName = result.fileName || "courses.csv";
  state.storage.dataPath = result.path || state.storage.dataPath;
  state.storage.status = "connected";
  state.storage.message = "";
  state.storage.lastSavedAt = new Date();
  renderStorageStatus();
}

async function writeCoursesToLocalServer() {
  const response = await fetch("./save-csv", {
    method: "POST",
    headers: { "Content-Type": "text/csv;charset=utf-8" },
    body: coursesToCsv(state.courses),
  });
  if (!response.ok) throw new Error(`Server CSV write failed: ${response.status}`);
  state.storage.connected = true;
  state.storage.backend = "server";
  state.storage.fileName = "courses.csv";
  state.storage.status = "connected";
  state.storage.message = "";
  state.storage.lastSavedAt = new Date();
  renderStorageStatus();
}

async function queryCsvPermission(handle, mode = "readwrite") {
  if (!handle?.queryPermission) return "granted";
  try {
    return await handle.queryPermission({ mode });
  } catch (error) {
    console.warn("CSV 权限查询失败", error);
    return "denied";
  }
}

async function verifyCsvPermission(handle, mode = "readwrite") {
  const options = { mode };
  if (!handle?.queryPermission || !handle?.requestPermission) return true;
  if ((await handle.queryPermission(options)) === "granted") return true;
  return (await handle.requestPermission(options)) === "granted";
}

function renderStorageStatus() {
  if (!els.storageStatus) return;
  const classes = ["storage-status"];
  if (state.storage.status === "connected") classes.push("is-connected");
  if (state.storage.status === "readonly") classes.push("is-readonly");
  if (state.storage.status === "warning") classes.push("is-warning");
  if (state.storage.status === "error") classes.push("is-error");
  els.storageStatus.className = classes.join(" ");

  if (state.storage.connected) {
    const savedText = state.storage.lastSavedAt ? ` · 已保存 ${formatSavedTime(state.storage.lastSavedAt)}` : "";
    if (state.storage.backend === "native") {
      els.storageStatus.textContent = `已连接 app 数据文件 ${state.storage.fileName || "courses.csv"}，修改会自动写入 Data 文件夹${savedText}`;
      return;
    }
    els.storageStatus.textContent = `已连接 ${state.storage.fileName || "courses.csv"}，修改会自动写入 CSV${savedText}`;
    return;
  }

  els.storageStatus.textContent = state.storage.message || "未连接 CSV 文件";
}

function formatSavedTime(date) {
  return date.toLocaleTimeString("zh-CN", {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

async function openHandleDatabase() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(FILE_DB_NAME, 1);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(FILE_STORE_NAME)) db.createObjectStore(FILE_STORE_NAME);
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function saveCsvHandle(handle) {
  try {
    const db = await openHandleDatabase();
    await storeValue(db, CSV_HANDLE_KEY, handle);
    db.close();
  } catch (error) {
    console.warn("CSV 文件授权句柄无法保存，重新打开页面后可能需要重新连接。", error);
  }
}

async function getSavedCsvHandle() {
  try {
    const db = await openHandleDatabase();
    const handle = await readValue(db, CSV_HANDLE_KEY);
    db.close();
    return handle || null;
  } catch (error) {
    console.warn("读取 CSV 文件授权句柄失败。", error);
    return null;
  }
}

function storeValue(db, key, value) {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(FILE_STORE_NAME, "readwrite");
    transaction.objectStore(FILE_STORE_NAME).put(value, key);
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error);
  });
}

function readValue(db, key) {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(FILE_STORE_NAME, "readonly");
    const request = transaction.objectStore(FILE_STORE_NAME).get(key);
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

function normalizeCourse(input) {
  if (!input || typeof input !== "object") return null;
  const day = normalizeDay(input.day);
  const room = normalizeRoom(input.room);
  const start = isTime(input.start) ? input.start : "16:00";
  const end = isTime(input.end) && timeToMinutes(input.end) > timeToMinutes(start) ? input.end : "17:00";
  return {
    id: String(input.id || createId()),
    name: cleanText(input.name, 60) || "未命名课程",
    category: cleanText(input.category, 32),
    classMode: normalizeClassMode(input.classMode),
    teacher: cleanText(input.teacher, 32),
    age: cleanText(input.age, 24),
    day,
    room,
    start,
    end,
    startDate: normalizeDateInput(input.startDate),
    endDate: normalizeDateInput(input.endDate),
    excludedDates: normalizeDateList(input.excludedDates),
    singlePrice: cleanText(input.singlePrice, 24),
    termPrice: cleanText(input.termPrice, 24),
    enrollments: normalizeEnrollments(input.enrollments || input.students),
    notes: cleanText(input.notes, 180),
    createdAt: input.createdAt || new Date().toISOString(),
    updatedAt: input.updatedAt || new Date().toISOString(),
  };
}

function renderAll() {
  renderOptionSets();
  renderTopline();
  renderScheduleControls();
  renderStorageStatus();
  renderSchedule();
  renderTable();
  renderStudents();
  renderEnrollment();
}

function renderTopline() {
  const count = state.courses.length;
  els.recordCount.textContent = `${count} ${count === 1 ? "class" : "classes"}`;
}

function renderScheduleControls() {
  setSegmentedActive(els.weekModeGroup, "weekMode", state.schedule.weekMode);
  setSegmentedActive(els.roomModeGroup, "roomMode", state.schedule.roomMode);
  els.scheduleZoom.value = String(state.schedule.zoom);
  els.scheduleZoomValue.textContent = `${state.schedule.zoom}%`;
}

function setSegmentedActive(group, suffix, value) {
  Array.from(group.querySelectorAll("button")).forEach((button) => {
    button.classList.toggle("is-active", button.dataset[suffix] === value);
  });
}

function setScheduleZoom(value) {
  const nextZoom = clampZoom(value);
  state.schedule.zoom = nextZoom;
  persistSchedulePrefs();
  renderScheduleControls();
  renderSchedule();
}

function clampZoom(value) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return DEFAULT_ZOOM;
  const stepped = Math.round(numeric / ZOOM_STEP) * ZOOM_STEP;
  return Math.min(ZOOM_MAX, Math.max(ZOOM_MIN, stepped));
}

function getTypographyScale(zoom) {
  const progress = (clampZoom(zoom) - ZOOM_MIN) / (ZOOM_MAX - ZOOM_MIN);
  return 0.8 + progress * 0.34;
}

function renderOptionSets() {
  const ageValues = uniqueValues("age");
  const categoryValues = uniqueValues("category");
  const teacherValues = uniqueValues("teacher");
  const studentValues = uniqueStudentNames();

  fillSelect(els.scheduleAgeFilter, ageValues, "全部年龄段", state.schedule.age);
  fillSelect(els.scheduleCategoryFilter, categoryValues, "全部课程", state.schedule.category);
  fillSelect(els.scheduleTeacherFilter, teacherValues, "全部老师", state.schedule.teacher);
  fillSelect(els.tableDayFilter, DAYS.map((day) => day.label), "全部星期", dayLabel(state.table.day), true);
  fillSelect(els.tableRoomFilter, ROOMS.map((room) => room.label), "全部教室", roomLabel(state.table.room), true);
  fillSelect(els.tableAgeFilter, ageValues, "全部年龄段", state.table.age);
  fillSelect(els.tableCategoryFilter, categoryValues, "全部课程", state.table.category);
  fillSelect(els.tableTeacherFilter, teacherValues, "全部老师", state.table.teacher);

  restoreIdSelect(els.tableDayFilter, state.table.day, DAYS, "label");
  restoreIdSelect(els.tableRoomFilter, state.table.room, ROOMS, "label");

  fillDatalist(els.categoryOptions, categoryValues);
  fillDatalist(els.teacherOptions, teacherValues);
  fillDatalist(els.ageOptions, ageValues);
  fillDatalist(els.studentOptions, studentValues);
}

function fillSelect(select, values, allLabel, currentValue, valuesAreLabels = false) {
  const existing = currentValue || select.value || "all";
  select.replaceChildren();
  select.append(new Option(allLabel, "all"));
  values.forEach((value) => {
    if (!value) return;
    select.append(new Option(value, valuesAreLabels ? value : value));
  });
  select.value = Array.from(select.options).some((option) => option.value === existing) ? existing : "all";
}

function restoreIdSelect(select, idValue, items, labelKey) {
  select.replaceChildren();
  select.append(new Option(select.id.includes("Day") ? "全部星期" : "全部教室", "all"));
  items.forEach((item) => select.append(new Option(item[labelKey], item.id)));
  select.value = items.some((item) => item.id === idValue) ? idValue : "all";
}

function fillDatalist(datalist, values) {
  datalist.replaceChildren();
  values.forEach((value) => datalist.append(new Option(value, value)));
}

function uniqueValues(key, defaults = []) {
  const values = new Set(defaults);
  state.courses.forEach((course) => {
    const value = cleanText(course[key], 80);
    if (value) values.add(value);
  });
  return Array.from(values).sort((a, b) => a.localeCompare(b, "zh-Hans-CN"));
}

function uniqueStudentNames() {
  const values = new Set();
  state.courses.forEach((course) => {
    normalizeEnrollments(course.enrollments).forEach((enrollment) => values.add(enrollment.name));
  });
  return Array.from(values).sort((a, b) => a.localeCompare(b, "zh-Hans-CN"));
}

function renderSchedule() {
  const days = state.schedule.weekMode === "full" ? DAYS : DAYS.slice(0, 5);
  const rooms = getVisibleRooms();
  const filteredCourses = getScheduleCourses(days, rooms);
  const roomText = rooms.length === 2 ? "大小教室" : rooms[0].label;
  const dayText = state.schedule.weekMode === "full" ? "周一到周日" : "周一到周五";
  const filterText = [
    dayText,
    roomText,
    state.schedule.age !== "all" ? state.schedule.age : "",
    state.schedule.category !== "all" ? state.schedule.category : "",
    state.schedule.teacher !== "all" ? state.schedule.teacher : "",
  ].filter(Boolean).join(" · ");

  els.scheduleSubtitle.textContent = filterText;
  els.printMeta.textContent = filterText;

  if (!state.courses.length) {
    renderScheduleEmpty("暂无课程", emptyScheduleMessage());
    return;
  }

  if (!filteredCourses.length) {
    renderScheduleEmpty("当前筛选没有课程", "换一个教室、年龄段、课程类型或老师。");
    return;
  }

  const timeRange = getTimeRange(filteredCourses);
  const zoomRatio = state.schedule.zoom / 100;
  const minuteHeight = getMinuteHeight(days.length, rooms.length) * zoomRatio;
  const hourHeight = 60 * minuteHeight;
  const timelineHeight = (timeRange.end - timeRange.start) * minuteHeight;
  const scale = getTypographyScale(state.schedule.zoom);
  const grid = document.createElement("div");
  const columnCount = days.length * rooms.length;
  const laneMinWidth = rooms.length === 2 ? 136 : 172;
  const columns = `68px repeat(${columnCount}, minmax(${laneMinWidth}px, 1fr))`;

  grid.className = "schedule-grid";
  grid.style.setProperty("--schedule-columns", columns);
  grid.style.setProperty("--schedule-min-width", `${68 + columnCount * laneMinWidth}px`);
  grid.style.setProperty("--timeline-height", `${timelineHeight}px`);
  grid.style.setProperty("--hour-height", `${hourHeight}px`);
  grid.style.setProperty("--course-title-size", `${(13 * scale).toFixed(1)}px`);
  grid.style.setProperty("--course-meta-size", `${(11 * scale).toFixed(1)}px`);
  grid.style.setProperty("--course-padding-y", `${(6 * scale).toFixed(1)}px`);
  grid.style.setProperty("--course-padding-x", `${(7 * scale).toFixed(1)}px`);
  grid.style.setProperty("--course-line-gap", `${(3 * scale).toFixed(1)}px`);
  grid.style.setProperty("--course-min-height", `${Math.round(32 * scale + (state.schedule.zoom - DEFAULT_ZOOM) * 0.06)}px`);
  grid.style.setProperty("--course-title-lines", state.schedule.zoom >= 135 ? "2" : "1");
  grid.style.setProperty("--course-meta-lines", state.schedule.zoom >= 160 ? "2" : "1");
  grid.style.setProperty("--course-foot-lines", state.schedule.zoom >= 150 ? "2" : "1");
  grid.style.setProperty("--print-columns", `52px repeat(${columnCount}, minmax(0, 1fr))`);
  grid.style.setProperty("--print-timeline-height", `${timelineHeight}px`);

  const header = document.createElement("div");
  header.className = "schedule-header";
  const corner = document.createElement("div");
  corner.className = "corner-cell";
  corner.textContent = "时间";
  header.append(corner);

  days.forEach((day) => {
    rooms.forEach((room) => {
      const cell = document.createElement("div");
      cell.className = `lane-header room-${room.id}`;
      const title = document.createElement("strong");
      title.textContent = day.label;
      const detail = document.createElement("span");
      detail.textContent = room.label;
      cell.append(title, detail);
      header.append(cell);
    });
  });

  const body = document.createElement("div");
  body.className = "schedule-body";
  const axis = document.createElement("div");
  axis.className = "time-axis";
  getTimeTicks(timeRange).forEach((minute) => {
    const tick = document.createElement("div");
    tick.className = "time-tick";
    tick.style.setProperty("--tick-top", `${(minute - timeRange.start) * minuteHeight}px`);
    tick.textContent = minutesToTimeLabel(minute);
    axis.append(tick);
  });
  body.append(axis);

  days.forEach((day) => {
    rooms.forEach((room) => {
      const lane = document.createElement("div");
      lane.className = `room-lane room-${room.id}`;
      const laneCourses = filteredCourses.filter((course) => course.day === day.id && course.room === room.id);
      buildEventLayout(laneCourses).forEach((item) => {
        lane.append(createCourseBlock(item, timeRange.start, minuteHeight));
      });
      body.append(lane);
    });
  });

  grid.append(header, body);
  els.scheduleBoard.replaceChildren(grid);
}

function renderScheduleEmpty(title, body) {
  const empty = document.createElement("div");
  empty.className = "empty-state";
  const content = document.createElement("div");
  const strong = document.createElement("strong");
  const text = document.createElement("span");
  strong.textContent = title;
  text.textContent = body;
  content.append(strong, text);
  empty.append(content);
  els.scheduleBoard.replaceChildren(empty);
}

function emptyScheduleMessage() {
  if (state.storage.message) return state.storage.message;
  return "点击添加课程后，这里会自动生成课程表。";
}

function getVisibleRooms() {
  if (state.schedule.roomMode === "large") return [ROOMS[0]];
  if (state.schedule.roomMode === "small") return [ROOMS[1]];
  return ROOMS;
}

function getScheduleCourses(days, rooms) {
  const daySet = new Set(days.map((day) => day.id));
  const roomSet = new Set(rooms.map((room) => room.id));
  return state.courses.filter((course) => {
    if (!daySet.has(course.day) || !roomSet.has(course.room)) return false;
    if (state.schedule.age !== "all" && course.age !== state.schedule.age) return false;
    if (state.schedule.category !== "all" && course.category !== state.schedule.category) return false;
    if (state.schedule.teacher !== "all" && course.teacher !== state.schedule.teacher) return false;
    return true;
  });
}

function getTimeRange(courses) {
  const starts = courses.map((course) => timeToMinutes(course.start));
  const ends = courses.map((course) => timeToMinutes(course.end));
  const first = Math.min(SCHEDULE_DEFAULT_START, ...starts);
  const last = Math.max(SCHEDULE_DEFAULT_END, ...ends);
  return {
    start: Math.max(0, floorToStep(first, SCHEDULE_RANGE_STEP)),
    end: Math.min(1440, ceilToStep(last, SCHEDULE_RANGE_STEP)),
  };
}

function getMinuteHeight(dayCount, roomCount) {
  if (dayCount >= 7 && roomCount === 2) return 0.54;
  if (dayCount >= 7) return 0.64;
  if (roomCount === 2) return 0.68;
  return 0.78;
}

function getTimeTicks(timeRange) {
  const ticks = new Set([timeRange.start, timeRange.end]);
  for (let hour = Math.ceil(timeRange.start / 60); hour <= Math.floor(timeRange.end / 60); hour += 1) {
    const minute = hour * 60;
    if (minute > timeRange.start && minute < timeRange.end) ticks.add(minute);
  }
  return Array.from(ticks).sort((a, b) => a - b);
}

function floorToStep(value, step) {
  return Math.floor(value / step) * step;
}

function ceilToStep(value, step) {
  return Math.ceil(value / step) * step;
}

function courseBlockFitScale(course, blockHeight, slots) {
  const requiredHeight = 46;
  const heightScale = Math.min(1, Math.max(0.58, blockHeight / requiredHeight));
  const longestText = Math.max(
    cleanText(course.name, 80).length,
    cleanText(course.category, 60).length,
    cleanText(course.teacher, 40).length + 12,
  );
  let textScale = 1;
  if (longestText > 20) textScale = 0.72;
  else if (longestText > 16) textScale = 0.8;
  else if (longestText > 12) textScale = 0.9;
  const slotScale = slots > 2 ? 0.76 : slots > 1 ? 0.88 : 1;
  return Math.min(1, Math.max(0.56, heightScale * textScale * slotScale));
}

function createCourseBlock(item, timelineStart, minuteHeight) {
  const course = item.course;
  const button = document.createElement("button");
  const start = timeToMinutes(course.start);
  const end = timeToMinutes(course.end);
  const palette = colorForCourse(course);
  const blockHeight = Math.max((end - start) * minuteHeight, 30);
  const fitScale = courseBlockFitScale(course, blockHeight, item.slots);
  button.type = "button";
  button.className = "course-block";
  button.style.setProperty("--top", `${(start - timelineStart) * minuteHeight}px`);
  button.style.setProperty("--height", `${(end - start) * minuteHeight}px`);
  button.style.setProperty("--slot", item.slot);
  button.style.setProperty("--slots", item.slots);
  button.style.setProperty("--accent", palette.accent);
  button.style.setProperty("--card-bg", palette.background);
  button.style.setProperty("--course-fit", fitScale.toFixed(2));
  button.style.setProperty("--course-title-size", `${(12.8 * fitScale).toFixed(1)}px`);
  button.style.setProperty("--course-meta-size", `${(10.5 * fitScale).toFixed(1)}px`);
  button.style.setProperty("--course-padding-y", `${(5.2 * fitScale).toFixed(1)}px`);
  button.style.setProperty("--course-padding-x", `${(6.4 * fitScale).toFixed(1)}px`);
  button.style.setProperty("--course-line-gap", `${Math.max(1, 2.4 * fitScale).toFixed(1)}px`);
  button.style.setProperty("--course-badge-size", `${Math.max(15, 19 * fitScale).toFixed(1)}px`);
  button.style.setProperty("--course-title-lines", blockHeight >= 48 && fitScale >= 0.72 ? "2" : "1");
  button.title = courseHoverText(course);
  button.addEventListener("click", () => openCourseDialog(course.id));

  const badge = document.createElement("span");
  badge.className = `course-mode-badge ${course.classMode === "private" ? "private" : "group"}`;
  badge.textContent = classModeShortLabel(course.classMode);

  const title = document.createElement("span");
  title.className = "course-title";
  title.textContent = course.name;
  const category = document.createElement("span");
  category.className = "course-category";
  category.textContent = course.category || "未分类";
  const meta = document.createElement("span");
  meta.className = "course-meta";
  meta.textContent = [course.teacher || "未设置老师", `${course.start}-${course.end}`].filter(Boolean).join(" · ");
  const content = document.createElement("span");
  content.className = "course-content";
  content.append(title, category, meta);
  button.append(badge, content, createCourseHoverCard(course));
  return button;
}

function createCourseHoverCard(course) {
  const card = document.createElement("span");
  card.className = "course-hover-card";

  const title = document.createElement("span");
  title.className = "hover-title";
  title.textContent = course.name;

  const detail = document.createElement("span");
  detail.className = "hover-detail";
  detail.textContent = [
    `${dayLabel(course.day)} ${course.start}-${course.end}`,
    course.teacher ? `老师 ${course.teacher}` : "未设置老师",
    course.category ? `分类 ${course.category}` : "未分类",
    course.age ? `年龄 ${course.age}` : "",
    roomLabel(course.room),
    classModeLabel(course.classMode),
    priceSummary(course),
    sessionSummary(course),
  ].filter(Boolean).join(" · ");

  card.append(title, detail);
  const enrollments = normalizeEnrollments(course.enrollments);
  if (!enrollments.length) {
    const empty = document.createElement("span");
    empty.className = "hover-empty";
    empty.textContent = "暂无报名学生";
    card.append(empty);
    return card;
  }

  card.append(
    createEnrollmentHoverGroup("按期", enrollments.filter((item) => item.type === "term"), "term"),
    createEnrollmentHoverGroup("按N次", enrollments.filter((item) => item.type === "passes"), "passes"),
  );
  return card;
}

function createEnrollmentHoverGroup(label, enrollments, type) {
  const group = document.createElement("span");
  group.className = "hover-group";
  const title = document.createElement("span");
  title.className = "hover-group-label";
  title.textContent = `${label} · ${enrollments.length} 人`;
  const row = document.createElement("span");
  row.className = "student-chip-row";
  if (enrollments.length) {
    enrollments.forEach((enrollment) => {
      const chip = document.createElement("span");
      chip.className = `student-chip ${type}`;
      chip.textContent = enrollment.name;
      row.append(chip);
    });
  } else {
    const empty = document.createElement("span");
    empty.className = "hover-empty";
    empty.textContent = "无";
    row.append(empty);
  }
  group.append(title, row);
  return group;
}

function buildEventLayout(courses) {
  const sorted = [...courses].sort((a, b) => timeToMinutes(a.start) - timeToMinutes(b.start));
  const groups = [];
  let group = [];
  let groupEnd = -1;

  sorted.forEach((course) => {
    const start = timeToMinutes(course.start);
    const end = timeToMinutes(course.end);
    if (!group.length || start < groupEnd) {
      group.push(course);
      groupEnd = Math.max(groupEnd, end);
    } else {
      groups.push(group);
      group = [course];
      groupEnd = end;
    }
  });
  if (group.length) groups.push(group);

  return groups.flatMap(layoutGroup);
}

function layoutGroup(group) {
  const columnEnds = [];
  const laidOut = group.map((course) => {
    const start = timeToMinutes(course.start);
    const end = timeToMinutes(course.end);
    let slot = columnEnds.findIndex((columnEnd) => columnEnd <= start);
    if (slot === -1) {
      slot = columnEnds.length;
      columnEnds.push(end);
    } else {
      columnEnds[slot] = end;
    }
    return { course, slot, slots: 1 };
  });
  const slots = Math.max(1, columnEnds.length);
  return laidOut.map((item) => ({ ...item, slots }));
}

function renderTable() {
  els.tableSearch.value = state.table.search;
  const filtered = getTableCourses();
  const sorted = sortCourses(filtered);
  els.courseTableBody.replaceChildren();

  if (!state.courses.length) {
    els.courseTableBody.append(createEmptyTableRow("暂无课程"));
    return;
  }

  if (!sorted.length) {
    els.courseTableBody.append(createEmptyTableRow("当前筛选没有课程"));
    return;
  }

  sorted.forEach((course) => els.courseTableBody.append(createTableRow(course)));
  renderSortHeaders();
}

function getTableCourses() {
  const query = state.table.search.toLowerCase();
  return state.courses.filter((course) => {
    if (state.table.day !== "all" && course.day !== state.table.day) return false;
    if (state.table.room !== "all" && course.room !== state.table.room) return false;
    if (state.table.age !== "all" && course.age !== state.table.age) return false;
    if (state.table.category !== "all" && course.category !== state.table.category) return false;
    if (state.table.teacher !== "all" && course.teacher !== state.table.teacher) return false;
    if (!query) return true;
    return [
      course.name,
      course.category,
      classModeLabel(course.classMode),
      course.teacher,
      course.age,
      course.singlePrice,
      course.termPrice,
      serializeEnrollments(course.enrollments),
      course.notes,
      dayLabel(course.day),
      roomLabel(course.room),
    ]
      .join(" ")
      .toLowerCase()
      .includes(query);
  });
}

function sortCourses(courses) {
  const dir = state.table.sortDir === "asc" ? 1 : -1;
  return [...courses].sort((a, b) => {
    const result = compareByKey(a, b, state.table.sortKey);
    return result * dir;
  });
}

function compareByKey(a, b, key) {
  if (key === "dayTime") {
    return dayOrder(a.day) - dayOrder(b.day) || timeToMinutes(a.start) - timeToMinutes(b.start);
  }
  if (key === "room") return roomLabel(a.room).localeCompare(roomLabel(b.room), "zh-Hans-CN");
  if (key === "name") return a.name.localeCompare(b.name, "zh-Hans-CN");
  if (key === "classMode") return classModeLabel(a.classMode).localeCompare(classModeLabel(b.classMode), "zh-Hans-CN");
  if (key === "category") return a.category.localeCompare(b.category, "zh-Hans-CN");
  if (key === "age") return a.age.localeCompare(b.age, "zh-Hans-CN");
  if (key === "teacher") return a.teacher.localeCompare(b.teacher, "zh-Hans-CN");
  return 0;
}

function renderSortHeaders() {
  document.querySelectorAll(".course-table th button[data-sort]").forEach((button) => {
    const active = button.dataset.sort === state.table.sortKey;
    const base = button.textContent.replace(/\s[↑↓]$/u, "");
    button.textContent = active ? `${base} ${state.table.sortDir === "asc" ? "↑" : "↓"}` : base;
  });
}

function createEmptyTableRow(text) {
  const row = document.createElement("tr");
  const cell = document.createElement("td");
  cell.colSpan = 9;
  cell.className = "empty-state";
  const content = document.createElement("div");
  const strong = document.createElement("strong");
  strong.textContent = text;
  content.append(strong);
  cell.append(content);
  row.append(cell);
  return row;
}

function createTableRow(course) {
  const row = document.createElement("tr");

  row.append(
    createStackCell(`${dayLabel(course.day)} ${course.start}-${course.end}`, durationLabel(course.start, course.end)),
    createTagCell(roomLabel(course.room)),
    createStackCell(course.name, course.notes),
    createStackCell(classModeLabel(course.classMode), [priceSummary(course), sessionSummary(course)].filter(Boolean).join(" · ") || "未设置价格"),
    createTextCell(course.category || "未分类"),
    createTextCell(course.age || "未设置"),
    createTextCell(course.teacher || "未设置"),
    createEnrollmentCell(course.enrollments),
    createActionsCell(course),
  );

  return row;
}

function createStackCell(primary, secondary) {
  const cell = document.createElement("td");
  const main = document.createElement("div");
  main.className = "table-primary";
  main.textContent = primary;
  cell.append(main);
  if (secondary) {
    const sub = document.createElement("div");
    sub.className = "table-secondary";
    sub.textContent = secondary;
    cell.append(sub);
  }
  return cell;
}

function createTagCell(text) {
  const cell = document.createElement("td");
  const tag = document.createElement("span");
  tag.className = "tag";
  tag.textContent = text;
  cell.append(tag);
  return cell;
}

function createTextCell(text) {
  const cell = document.createElement("td");
  cell.textContent = text;
  return cell;
}

function createEnrollmentCell(enrollments) {
  const cell = document.createElement("td");
  const counts = enrollmentCounts(enrollments);
  const main = document.createElement("div");
  main.className = "table-primary";
  main.textContent = `${counts.total} 人`;
  const sub = document.createElement("div");
  sub.className = "table-secondary";
  sub.textContent = counts.total ? `按期 ${counts.term} · 按N次 ${counts.passes}` : "未报名";
  cell.append(main, sub);
  return cell;
}

function renderStudents() {
  if (!els.studentBoard) return;
  els.studentSearch.value = state.students.search;
  els.studentEnrollmentFilter.value = state.students.enrollmentType;
  const records = getFilteredStudentRecords();
  const totalRegistrations = records.reduce((sum, student) => sum + student.items.length, 0);
  els.studentsSubtitle.textContent = `${records.length} 个学生 · ${totalRegistrations} 门报名课程`;
  els.studentBoard.replaceChildren();

  if (!records.length) {
    const empty = document.createElement("div");
    empty.className = "empty-state";
    const content = document.createElement("div");
    const strong = document.createElement("strong");
    const text = document.createElement("span");
    strong.textContent = state.courses.length ? "当前筛选没有学生" : "暂无报名学生";
    text.textContent = state.courses.length ? "换一个搜索词或报名方式。" : "在课程设置里给课程添加报名学生后，这里会自动汇总。";
    content.append(strong, text);
    empty.append(content);
    els.studentBoard.append(empty);
    return;
  }

  els.studentBoard.append(createStudentTable(records));
}

function getFilteredStudentRecords() {
  const query = state.students.search.toLowerCase();
  const typeFilter = state.students.enrollmentType;
  return getStudentRecords().map((student) => {
    const items = student.items.filter((item) => {
      if (typeFilter !== "all" && item.enrollment.type !== typeFilter) return false;
      if (!query) return true;
      return [
        student.name,
        item.course.name,
        item.course.category,
        item.course.teacher,
        item.course.age,
        dayLabel(item.course.day),
        roomLabel(item.course.room),
        enrollmentTypeLabel(item.enrollment.type),
      ].join(" ").toLowerCase().includes(query);
    });
    return { ...student, items };
  }).filter((student) => student.items.length)
    .sort((a, b) => a.name.localeCompare(b.name, "zh-Hans-CN"));
}

function getStudentRecords() {
  const records = new Map();
  state.courses.forEach((course) => {
    normalizeEnrollments(course.enrollments).forEach((enrollment) => {
      if (!records.has(enrollment.name)) {
        records.set(enrollment.name, { name: enrollment.name, items: [] });
      }
      records.get(enrollment.name).items.push({ course, enrollment });
    });
  });

  return Array.from(records.values()).map((student) => ({
    ...student,
    items: student.items.sort((a, b) => {
      return dayOrder(a.course.day) - dayOrder(b.course.day) || timeToMinutes(a.course.start) - timeToMinutes(b.course.start);
    }),
  }));
}

function renderEnrollment() {
  if (!els.enrollmentBoard) return;
  els.enrollmentSearch.value = state.enrollment.search;
  els.enrollmentTypeFilter.value = state.enrollment.enrollmentType;
  const records = getFilteredEnrollmentRecords();
  const studentCount = new Set(records.map((record) => record.studentName)).size;
  const courseCount = new Set(records.map((record) => record.course.id)).size;
  els.enrollmentSubtitle.textContent = `${records.length} 条报名 · ${studentCount} 个学生 · ${courseCount} 门课程`;
  els.enrollmentBoard.replaceChildren();

  if (!records.length) {
    const empty = document.createElement("div");
    empty.className = "empty-state";
    const content = document.createElement("div");
    const strong = document.createElement("strong");
    const text = document.createElement("span");
    strong.textContent = state.courses.length ? "当前筛选没有报名记录" : "暂无报名记录";
    text.textContent = state.courses.length ? "换一个搜索词或报名方式。" : "在课程设置或学生页添加报名后，这里会自动汇总。";
    content.append(strong, text);
    empty.append(content);
    els.enrollmentBoard.append(empty);
    return;
  }

  els.enrollmentBoard.append(createEnrollmentTable(records));
}

function getFilteredEnrollmentRecords() {
  const query = state.enrollment.search.toLowerCase();
  const typeFilter = state.enrollment.enrollmentType;
  return getEnrollmentRecords().filter((record) => {
    if (typeFilter !== "all" && record.enrollment.type !== typeFilter) return false;
    if (!query) return true;
    const course = record.course;
    return [
      record.studentName,
      course.name,
      course.category,
      course.teacher,
      course.age,
      dayLabel(course.day),
      roomLabel(course.room),
      classModeLabel(course.classMode),
      enrollmentTypeLabel(record.enrollment.type),
    ].join(" ").toLowerCase().includes(query);
  });
}

function getEnrollmentRecords() {
  return state.courses.flatMap((course) => {
    return normalizeEnrollments(course.enrollments).map((enrollment) => ({
      course,
      enrollment,
      studentName: enrollment.name,
    }));
  }).sort((a, b) => {
    return a.studentName.localeCompare(b.studentName, "zh-Hans-CN")
      || dayOrder(a.course.day) - dayOrder(b.course.day)
      || timeToMinutes(a.course.start) - timeToMinutes(b.course.start)
      || a.course.name.localeCompare(b.course.name, "zh-Hans-CN");
  });
}

function createEnrollmentTable(records) {
  const table = document.createElement("table");
  table.className = "course-table enrollment-table";

  const thead = document.createElement("thead");
  const headRow = document.createElement("tr");
  ["学生", "课程", "星期 / 时间", "教室", "老师", "课程类型", "年龄段", "报名方式", "价格", "上课周次", "查看"].forEach((label) => {
    const th = document.createElement("th");
    th.textContent = label;
    headRow.append(th);
  });
  thead.append(headRow);

  const tbody = document.createElement("tbody");
  records.forEach((record) => tbody.append(createEnrollmentTableRow(record)));
  table.append(thead, tbody);
  return table;
}

function createEnrollmentTableRow(record) {
  const { course, enrollment, studentName } = record;
  const row = document.createElement("tr");
  row.append(
    createStackCell(studentName, enrollmentTypeLabel(enrollment.type)),
    createStackCell(course.name, classModeLabel(course.classMode)),
    createStackCell(`${dayLabel(course.day)} ${course.start}-${course.end}`, durationLabel(course.start, course.end)),
    createTagCell(roomLabel(course.room)),
    createTextCell(course.teacher || "未设置"),
    createTextCell(course.category || "未分类"),
    createTextCell(course.age || "未设置"),
    createTextCell(enrollmentTypeLabel(enrollment.type)),
    createTextCell(enrollmentPriceLabel(course, enrollment)),
    createTextCell(sessionSummary(course) || "未设置"),
    createEnrollmentViewCell(course, enrollment, studentName),
  );
  return row;
}

function createEnrollmentViewCell(course, enrollment, studentName) {
  const cell = document.createElement("td");
  const wrap = document.createElement("div");
  wrap.className = "row-actions";
  const view = document.createElement("button");
  view.type = "button";
  view.textContent = "查看";
  view.addEventListener("click", () => openReadonlyCourseDialog(course.id, studentName, enrollment.type));
  wrap.append(view);
  cell.append(wrap);
  return cell;
}

function createStudentTable(records) {
  const table = document.createElement("table");
  table.className = "student-table";

  const thead = document.createElement("thead");
  const headRow = document.createElement("tr");
  ["学生", "报名课程", "课程数", "报名方式", "预估应付", "添加"].forEach((label) => {
    const th = document.createElement("th");
    th.textContent = label;
    headRow.append(th);
  });
  thead.append(headRow);

  const tbody = document.createElement("tbody");
  records.forEach((student) => tbody.append(createStudentTableRow(student)));

  table.append(thead, tbody);
  return table;
}

function createStudentTableRow(student) {
  const row = document.createElement("tr");
  const counts = studentEnrollmentCounts(student.items);

  row.append(
    createStackCell(student.name, `${student.items.length} 门课`),
    createStudentCoursesCell(student),
    createTextCell(String(student.items.length)),
    createTextCell(`按期 ${counts.term} · 按N次 ${counts.passes}`),
    createTextCell(studentPaymentSummary(student.items)),
    createStudentActionsCell(student),
  );

  return row;
}

function createStudentCoursesCell(student) {
  const cell = document.createElement("td");
  const list = document.createElement("div");
  list.className = "student-course-list";
  student.items.forEach((item) => list.append(createStudentCourseBlock(student.name, item)));
  cell.append(list);
  return cell;
}

function createStudentActionsCell(student) {
  const cell = document.createElement("td");
  const wrap = document.createElement("div");
  wrap.className = "row-actions";

  const add = document.createElement("button");
  add.type = "button";
  add.textContent = "添加课程";
  add.title = "从现有课程里给这个学生添加一门课";
  add.addEventListener("click", () => openStudentEnrollDialog(student.name));

  wrap.append(add);
  cell.append(wrap);
  return cell;
}

function createStudentCourseBlock(studentName, item) {
  const { course, enrollment } = item;
  const block = document.createElement("div");
  block.className = `student-course-block ${enrollment.type}`;
  block.title = studentCourseHoverText(course, enrollment);

  const detailButton = document.createElement("button");
  detailButton.type = "button";
  detailButton.className = "student-course-main";
  detailButton.addEventListener("click", () => openReadonlyCourseDialog(course.id, studentName, enrollment.type));

  const removeButton = document.createElement("button");
  removeButton.type = "button";
  removeButton.className = "student-course-remove";
  removeButton.textContent = "×";
  removeButton.setAttribute("aria-label", `从 ${studentName} 删除 ${course.name}`);
  removeButton.title = "从这个学生的报名里删除这门课";
  removeButton.addEventListener("click", () => removeStudentEnrollment(course.id, studentName, enrollment.type));

  const line = document.createElement("span");
  line.className = "student-course-line";
  line.textContent = `${dayLabel(course.day)} ${course.start} · ${course.name} · ${enrollmentTypeLabel(enrollment.type)}`;
  const meta = document.createElement("span");
  meta.className = "student-course-meta";
  meta.textContent = [roomLabel(course.room), course.teacher, course.category || "未分类"].filter(Boolean).join(" · ");
  const money = document.createElement("span");
  money.className = "student-course-money";
  money.textContent = enrollmentPriceLabel(course, enrollment);

  const hover = document.createElement("span");
  hover.className = "student-course-hover";
  studentCourseDetailLines(course, enrollment).forEach((text) => {
    const itemLine = document.createElement("span");
    itemLine.textContent = text;
    hover.append(itemLine);
  });

  detailButton.append(line, meta, money);
  block.append(detailButton, removeButton, hover);
  return block;
}

async function removeStudentEnrollment(courseId, studentName, enrollmentType) {
  const course = state.courses.find((item) => item.id === courseId);
  if (!course) return;
  if (!confirm(`从「${studentName}」删除「${course.name}」？`)) return;

  const nextCourses = state.courses.map((item) => {
    if (item.id !== courseId) return item;
    return {
      ...item,
      enrollments: normalizeEnrollments(item.enrollments).filter((enrollment) => {
        return enrollment.name !== studentName || enrollment.type !== enrollmentType;
      }),
      updatedAt: new Date().toISOString(),
    };
  });
  await commitCourses(nextCourses);
}

function openStudentEnrollDialog(studentName) {
  const availableCourses = coursesAvailableForStudent(studentName);
  if (!availableCourses.length) {
    alert("当前没有可添加的课程。这个学生已经报名了所有现有课程。");
    return;
  }

  els.studentEnrollForm.reset();
  els.studentEnrollName.value = studentName;
  els.studentEnrollTitle.textContent = `给 ${studentName} 添加课程`;
  els.studentEnrollSubtitle.textContent = "从现有课程里选择";
  els.studentEnrollCourse.replaceChildren();
  availableCourses.forEach((course) => {
    els.studentEnrollCourse.append(new Option(studentCourseOptionLabel(course), course.id));
  });
  els.studentEnrollType.value = "term";
  els.studentEnrollDialog.showModal();
}

function closeStudentEnrollDialog() {
  els.studentEnrollDialog.close();
}

async function addCourseToStudentFromDialog(event) {
  event.preventDefault();
  const studentName = cleanText(els.studentEnrollName.value, 40);
  const courseId = els.studentEnrollCourse.value;
  const enrollmentType = normalizeEnrollmentType(els.studentEnrollType.value);
  if (!studentName || !courseId) return;

  const nextCourses = state.courses.map((course) => {
    if (course.id !== courseId) return course;
    const enrollments = normalizeEnrollments(course.enrollments);
    if (enrollments.some((enrollment) => enrollment.name === studentName)) return course;
    return {
      ...course,
      enrollments: [...enrollments, { name: studentName, type: enrollmentType }],
      updatedAt: new Date().toISOString(),
    };
  });

  const saved = await commitCourses(nextCourses);
  if (saved) closeStudentEnrollDialog();
}

function coursesAvailableForStudent(studentName) {
  return [...state.courses]
    .filter((course) => {
      return !normalizeEnrollments(course.enrollments).some((enrollment) => enrollment.name === studentName);
    })
    .sort((a, b) => {
      return dayOrder(a.day) - dayOrder(b.day) || timeToMinutes(a.start) - timeToMinutes(b.start) || a.name.localeCompare(b.name, "zh-Hans-CN");
    });
}

function studentCourseOptionLabel(course) {
  return [
    `${dayLabel(course.day)} ${course.start}-${course.end}`,
    course.name,
    roomLabel(course.room),
    course.teacher || "未设置老师",
  ].filter(Boolean).join(" · ");
}

function studentEnrollmentCounts(items) {
  return items.reduce((counts, item) => {
    counts[item.enrollment.type] = (counts[item.enrollment.type] || 0) + 1;
    return counts;
  }, { term: 0, passes: 0 });
}

function studentPaymentSummary(items) {
  const result = calculateStudentPayment(items);
  if (!result.knownCount) return "预估应付：待定";
  const amount = formatMoney(result.amount, result.currency);
  return result.missingCount ? `预估应付：${amount} · ${result.missingCount} 项待定` : `预估应付：${amount}`;
}

function calculateStudentPayment(items) {
  return items.reduce((result, item) => {
    const parsed = parsePriceAmount(priceForEnrollment(item.course, item.enrollment));
    if (!parsed) {
      result.missingCount += 1;
      return result;
    }
    result.amount += parsed.amount;
    result.knownCount += 1;
    if (!result.currency && parsed.currency) result.currency = parsed.currency;
    if (result.currency && parsed.currency && result.currency !== parsed.currency) result.mixedCurrency = true;
    return result;
  }, { amount: 0, currency: "", knownCount: 0, missingCount: 0, mixedCurrency: false });
}

function priceForEnrollment(course, enrollment) {
  return enrollment.type === "term" ? course.termPrice : course.singlePrice;
}

function enrollmentPriceLabel(course, enrollment) {
  const price = priceForEnrollment(course, enrollment);
  return price ? `${enrollmentTypeLabel(enrollment.type)} ${price}` : `${enrollmentTypeLabel(enrollment.type)} 待定`;
}

function parsePriceAmount(value) {
  const text = cleanText(value, 40).replace(/,/g, "");
  if (!text) return null;
  const match = text.match(/([$¥￥])?\s*([0-9]+(?:\.[0-9]+)?)/u);
  if (!match) return null;
  const suffixCurrency = text.match(/([¥￥$])\s*$/u)?.[1] || "";
  return {
    currency: normalizeCurrency(match[1] || suffixCurrency),
    amount: Number(match[2]),
  };
}

function normalizeCurrency(value) {
  if (value === "￥") return "¥";
  return value || "";
}

function formatMoney(amount, currency) {
  const rounded = Number.isInteger(amount) ? String(amount) : amount.toFixed(2).replace(/0+$/u, "").replace(/\.$/u, "");
  return `${currency || ""}${rounded}`;
}

function studentCourseHoverText(course, enrollment) {
  return studentCourseDetailLines(course, enrollment).join("\n");
}

function studentCourseDetailLines(course, enrollment) {
  return [
    `${dayLabel(course.day)} ${course.start}-${course.end}`,
    `${course.name} · ${enrollmentTypeLabel(enrollment.type)}`,
    [roomLabel(course.room), course.teacher, classModeLabel(course.classMode)].filter(Boolean).join(" · "),
    sessionSummary(course),
    enrollmentPriceLabel(course, enrollment),
  ].filter(Boolean);
}

function createActionsCell(course) {
  const cell = document.createElement("td");
  const wrap = document.createElement("div");
  wrap.className = "row-actions";
  const edit = document.createElement("button");
  const copy = document.createElement("button");
  const del = document.createElement("button");
  edit.type = copy.type = del.type = "button";
  edit.textContent = "编辑";
  copy.textContent = "复制";
  del.textContent = "删除";
  del.className = "delete-row";
  edit.addEventListener("click", () => openCourseDialog(course.id));
  copy.addEventListener("click", () => duplicateCourse(course.id));
  del.addEventListener("click", () => deleteCourse(course.id));
  wrap.append(edit, copy, del);
  cell.append(wrap);
  return cell;
}

function openReadonlyCourseDialog(courseId, studentName, enrollmentType) {
  const course = state.courses.find((item) => item.id === courseId);
  if (!course) return;
  const enrollment = normalizeEnrollments(course.enrollments).find((item) => {
    return item.name === studentName && item.type === enrollmentType;
  }) || { name: studentName, type: enrollmentType };

  els.readonlyCourseTitle.textContent = course.name;
  els.readonlyCourseSubtitle.textContent = `${enrollment.name} · ${enrollmentTypeLabel(enrollment.type)}`;
  els.readonlyCourseBody.replaceChildren(
    createReadonlySection("上课信息", [
      ["星期", dayLabel(course.day)],
      ["时间", `${course.start}-${course.end}`],
      ["教室", roomLabel(course.room)],
      ["老师", course.teacher || "未设置"],
      ["属性", classModeLabel(course.classMode)],
    ]),
    createReadonlySection("课程信息", [
      ["课程类型", course.category || "未分类"],
      ["年龄段", course.age || "未设置"],
      ["报名方式", enrollmentTypeLabel(enrollment.type)],
      ["本次计费", enrollmentPriceLabel(course, enrollment)],
    ]),
    createReadonlySection("价格", [
      ["单期价格", course.singlePrice || "未设置"],
      ["按期价格", course.termPrice || "未设置"],
    ]),
    createReadonlySection("上课周次", [
      ["起始周", course.startDate || "未设置"],
      ["结束周", course.endDate || "未设置"],
      ["有效周数", sessionSummary(course) || "未设置"],
      ["停课日期", serializeDateList(course.excludedDates) || "无"],
    ]),
    createReadonlySection("备注", [
      ["备注", course.notes || "无"],
    ]),
  );
  els.readonlyCourseDialog.showModal();
}

function closeReadonlyCourseDialog() {
  els.readonlyCourseDialog.close();
}

function createReadonlySection(title, rows) {
  const section = document.createElement("section");
  section.className = "readonly-section";
  const heading = document.createElement("h3");
  heading.textContent = title;
  const list = document.createElement("dl");
  rows.forEach(([label, value]) => {
    const dt = document.createElement("dt");
    const dd = document.createElement("dd");
    dt.textContent = label;
    dd.textContent = value;
    list.append(dt, dd);
  });
  section.append(heading, list);
  return section;
}

function openCourseDialog(courseId) {
  const course = courseId ? state.courses.find((item) => item.id === courseId) : null;
  els.courseForm.reset();
  els.courseId.value = course?.id || "";
  els.courseName.value = course?.name || "";
  els.courseCategory.value = course?.category || "";
  els.courseClassMode.value = course?.classMode || "group";
  els.courseTeacher.value = course?.teacher || "";
  els.courseAge.value = course?.age || "";
  els.courseDay.value = course?.day || "mon";
  els.courseRoom.value = course?.room || "large";
  els.courseStartDate.value = course?.startDate || "";
  els.courseEndDate.value = course?.endDate || "";
  els.courseStart.value = course?.start || "16:00";
  els.courseEnd.value = course?.end || "17:00";
  els.courseSinglePrice.value = course?.singlePrice || "";
  els.courseTermPrice.value = course?.termPrice || "";
  els.courseNotes.value = course?.notes || "";
  formExcludedDates = new Set(normalizeDateList(course?.excludedDates || []));
  renderSessionPreview();
  renderEnrollmentRows(course?.enrollments || []);
  els.dialogTitle.textContent = course ? "编辑课程" : "添加课程";
  els.dialogSubtitle.textContent = course ? `${dayLabel(course.day)} · ${roomLabel(course.room)}` : "课程信息";
  renderConflictNotice();
  els.courseDialog.showModal();
  els.courseName.focus();
}

function closeCourseDialog() {
  els.courseDialog.close();
}

function renderSessionPreview() {
  if (!els.sessionList) return;
  const sessions = getCourseSessionDates({
    day: els.courseDay.value,
    startDate: els.courseStartDate.value,
    endDate: els.courseEndDate.value,
    excludedDates: Array.from(formExcludedDates),
  });
  const allSessions = getCourseSessionDates({
    day: els.courseDay.value,
    startDate: els.courseStartDate.value,
    endDate: els.courseEndDate.value,
    excludedDates: [],
  });
  formExcludedDates = new Set(Array.from(formExcludedDates).filter((date) => {
    return allSessions.some((session) => session.date === date);
  }));

  els.sessionList.replaceChildren();
  if (!els.courseStartDate.value || !els.courseEndDate.value) {
    els.sessionCount.textContent = "未设置日期范围";
    appendSessionEmpty("选择起始周和结束周后，会自动生成每周上课日期。");
    return;
  }

  if (!allSessions.length) {
    els.sessionCount.textContent = "0 周";
    appendSessionEmpty("这个日期范围内没有匹配当前星期的上课日期。");
    return;
  }

  els.sessionCount.textContent = `${sessions.length} / ${allSessions.length} 周`;
  if (!sessions.length) {
    appendSessionEmpty("所有周次都已被扣掉。");
    return;
  }

  sessions.forEach((session, index) => els.sessionList.append(createSessionChip(session, index + 1)));
}

function appendSessionEmpty(text) {
  const empty = document.createElement("div");
  empty.className = "session-empty";
  empty.textContent = text;
  els.sessionList.append(empty);
}

function createSessionChip(session, index) {
  const chip = document.createElement("div");
  chip.className = "session-chip";
  const title = document.createElement("strong");
  title.textContent = `${index}. ${formatDisplayDate(session.date)}`;
  const sub = document.createElement("span");
  sub.textContent = session.dayLabel;
  const remove = document.createElement("button");
  remove.className = "remove-session";
  remove.type = "button";
  remove.dataset.date = session.date;
  remove.setAttribute("aria-label", `扣掉 ${session.date}`);
  remove.textContent = "×";
  chip.append(title, sub, remove);
  return chip;
}

function renderEnrollmentRows(enrollments) {
  els.enrollmentList.replaceChildren();
  normalizeEnrollments(enrollments).forEach((enrollment) => addEnrollmentRow(enrollment));
  ensureEnrollmentPlaceholder();
}

function addEnrollmentRow(enrollment = {}) {
  removeEnrollmentPlaceholder();
  const row = document.createElement("div");
  row.className = "enrollment-row";

  const nameInput = document.createElement("input");
  nameInput.className = "enrollment-name";
  nameInput.type = "text";
  nameInput.maxLength = 40;
  nameInput.placeholder = "学生姓名";
  nameInput.setAttribute("list", "studentOptions");
  nameInput.value = enrollment.name || "";

  const typeSelect = document.createElement("select");
  typeSelect.className = "enrollment-type";
  ENROLLMENT_TYPES.forEach((type) => typeSelect.append(new Option(type.label, type.id)));
  typeSelect.value = normalizeEnrollmentType(enrollment.type);

  const removeButton = document.createElement("button");
  removeButton.className = "remove-enrollment";
  removeButton.type = "button";
  removeButton.setAttribute("aria-label", "删除学生");
  removeButton.textContent = "×";

  row.append(nameInput, typeSelect, removeButton);
  els.enrollmentList.append(row);
  nameInput.focus();
}

function ensureEnrollmentPlaceholder() {
  if (els.enrollmentList.querySelector(".enrollment-row")) return;
  const empty = document.createElement("div");
  empty.className = "enrollment-empty";
  empty.textContent = "暂无报名学生";
  els.enrollmentList.append(empty);
}

function removeEnrollmentPlaceholder() {
  els.enrollmentList.querySelector(".enrollment-empty")?.remove();
}

function readEnrollmentsFromForm() {
  return Array.from(els.enrollmentList.querySelectorAll(".enrollment-row")).map((row) => ({
    name: row.querySelector(".enrollment-name")?.value || "",
    type: row.querySelector(".enrollment-type")?.value || "term",
  })).map(normalizeEnrollment).filter(Boolean);
}

async function saveCourseFromForm(event) {
  event.preventDefault();
  const data = normalizeCourse({
    id: els.courseId.value || createId(),
    name: els.courseName.value,
    category: els.courseCategory.value,
    classMode: els.courseClassMode.value,
    teacher: els.courseTeacher.value,
    age: els.courseAge.value,
    day: els.courseDay.value,
    room: els.courseRoom.value,
    start: els.courseStart.value,
    end: els.courseEnd.value,
    startDate: els.courseStartDate.value,
    endDate: els.courseEndDate.value,
    excludedDates: Array.from(formExcludedDates),
    singlePrice: els.courseSinglePrice.value,
    termPrice: els.courseTermPrice.value,
    enrollments: readEnrollmentsFromForm(),
    notes: els.courseNotes.value,
    createdAt: state.courses.find((course) => course.id === els.courseId.value)?.createdAt,
    updatedAt: new Date().toISOString(),
  });

  const error = validateCourse(data);
  if (error) {
    alert(error);
    return;
  }

  const nextCourses = [...state.courses];
  const index = nextCourses.findIndex((course) => course.id === data.id);
  if (index >= 0) {
    nextCourses.splice(index, 1, data);
  } else {
    nextCourses.push(data);
  }

  const saved = await commitCourses(nextCourses);
  if (saved) {
    closeCourseDialog();
  }
}

function validateCourse(course) {
  if (!course.name) return "请填写课程名称。";
  if (!isTime(course.start) || !isTime(course.end)) return "请填写开始和结束时间。";
  if (timeToMinutes(course.start) >= timeToMinutes(course.end)) return "结束时间需要晚于开始时间。";
  if (course.startDate && course.endDate && course.startDate > course.endDate) return "结束周需要晚于或等于起始周。";
  return "";
}

function renderConflictNotice() {
  const draft = normalizeCourse({
    id: els.courseId.value || "__draft__",
    name: els.courseName.value || "当前课程",
    day: els.courseDay.value,
    room: els.courseRoom.value,
    start: els.courseStart.value,
    end: els.courseEnd.value,
  });
  if (!draft || timeToMinutes(draft.start) >= timeToMinutes(draft.end)) {
    els.conflictBox.hidden = true;
    return;
  }
  const conflicts = findConflicts(draft);
  if (!conflicts.length) {
    els.conflictBox.hidden = true;
    return;
  }
  els.conflictBox.hidden = false;
  els.conflictBox.textContent = `时间重叠：${conflicts.map((course) => `${course.name}（${course.start}-${course.end}）`).join("、")}`;
}

function findConflicts(target) {
  const start = timeToMinutes(target.start);
  const end = timeToMinutes(target.end);
  return state.courses.filter((course) => {
    if (course.id === target.id) return false;
    if (course.day !== target.day || course.room !== target.room) return false;
    return start < timeToMinutes(course.end) && end > timeToMinutes(course.start);
  });
}

async function duplicateCourse(courseId) {
  const source = state.courses.find((course) => course.id === courseId);
  if (!source) return;
  const copy = normalizeCourse({
    ...source,
    id: createId(),
    name: `${source.name} 复制`,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  });
  await commitCourses([...state.courses, copy]);
}

async function deleteCourse(courseId) {
  const course = state.courses.find((item) => item.id === courseId);
  if (!course) return;
  if (!confirm(`删除「${course.name}」？`)) return;
  await commitCourses(state.courses.filter((item) => item.id !== courseId));
}

async function clearCourses() {
  if (!state.courses.length) return;
  if (!confirm("清空全部课程？")) return;
  await commitCourses([]);
}

function exportCourses() {
  const blob = new Blob([coursesToCsv(state.courses)], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  const stamp = new Date().toISOString().slice(0, 10);
  link.href = url;
  link.download = `jiamei-courses-${stamp}.csv`;
  document.body.append(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}

function importCourses(event) {
  const [file] = event.target.files;
  if (!file) return;
  const reader = new FileReader();
  reader.onload = async () => {
    try {
      const text = String(reader.result);
      const normalized = file.name.toLowerCase().endsWith(".json")
        ? parseCoursesJson(text)
        : parseCoursesCsv(text);
      if (!confirm(`导入 ${normalized.length} 门课程并替换当前数据？`)) return;
      await commitCourses(normalized);
    } catch (error) {
      alert("导入失败，请选择正确的 CSV 或 JSON 文件。");
      console.error(error);
    } finally {
      els.importFile.value = "";
    }
  };
  reader.readAsText(file);
}

function coursesToCsv(courses) {
  const rows = [
    CSV_COLUMNS.map((column) => column.label),
    ...courses.map((course) => CSV_COLUMNS.map((column) => csvValueForCourse(course, column.key))),
  ];
  return `\uFEFF${rows.map((row) => row.map(escapeCsvCell).join(",")).join("\r\n")}\r\n`;
}

function csvValueForCourse(course, key) {
  if (key === "day") return dayLabel(course.day);
  if (key === "room") return roomLabel(course.room);
  if (key === "classMode") return classModeLabel(course.classMode);
  if (key === "enrollments") return serializeEnrollments(course.enrollments);
  if (key === "excludedDates") return serializeDateList(course.excludedDates);
  return course[key] || "";
}

function escapeCsvCell(value) {
  const text = String(value ?? "");
  if (/[",\r\n]/.test(text)) return `"${text.replace(/"/g, '""')}"`;
  return text;
}

function parseCoursesCsv(text) {
  const rows = parseCsvRows(text).filter((row) => row.some((cell) => cleanText(cell, 100)));
  if (!rows.length) return [];
  const headers = rows[0].map((header) => cleanText(header.replace(/^\uFEFF/, ""), 60));
  return rows.slice(1).map((row) => {
    const record = {};
    headers.forEach((header, index) => {
      record[header] = row[index] || "";
    });
    return normalizeCourse({
      id: readCsvRecordValue(record, "id"),
      name: readCsvRecordValue(record, "name"),
      category: readCsvRecordValue(record, "category"),
      classMode: readCsvRecordValue(record, "classMode"),
      teacher: readCsvRecordValue(record, "teacher"),
      age: readCsvRecordValue(record, "age"),
      day: readCsvRecordValue(record, "day"),
      room: readCsvRecordValue(record, "room"),
      start: readCsvRecordValue(record, "start"),
      end: readCsvRecordValue(record, "end"),
      startDate: readCsvRecordValue(record, "startDate"),
      endDate: readCsvRecordValue(record, "endDate"),
      excludedDates: readCsvRecordValue(record, "excludedDates"),
      singlePrice: readCsvRecordValue(record, "singlePrice"),
      termPrice: readCsvRecordValue(record, "termPrice"),
      enrollments: readCsvRecordValue(record, "enrollments"),
      notes: readCsvRecordValue(record, "notes"),
      createdAt: readCsvRecordValue(record, "createdAt"),
      updatedAt: readCsvRecordValue(record, "updatedAt"),
    });
  }).filter(Boolean);
}

function parseCsvRows(text) {
  const rows = [];
  let row = [];
  let cell = "";
  let inQuotes = false;
  const source = String(text || "").replace(/^\uFEFF/, "");

  for (let index = 0; index < source.length; index += 1) {
    const char = source[index];
    const next = source[index + 1];

    if (char === '"') {
      if (inQuotes && next === '"') {
        cell += '"';
        index += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (char === "," && !inQuotes) {
      row.push(cell);
      cell = "";
      continue;
    }

    if ((char === "\n" || char === "\r") && !inQuotes) {
      if (char === "\r" && next === "\n") index += 1;
      row.push(cell);
      rows.push(row);
      row = [];
      cell = "";
      continue;
    }

    cell += char;
  }

  if (cell || row.length) {
    row.push(cell);
    rows.push(row);
  }

  return rows;
}

function readCsvRecordValue(record, key) {
  const column = CSV_COLUMNS.find((item) => item.key === key);
  const names = [column?.label, ...(column?.aliases || [])].filter(Boolean);
  for (const name of names) {
    if (Object.prototype.hasOwnProperty.call(record, name)) return record[name];
  }
  return "";
}

function parseCoursesJson(text) {
  const parsed = JSON.parse(text);
  const incoming = Array.isArray(parsed) ? parsed : parsed.courses;
  if (!Array.isArray(incoming)) throw new Error("Invalid import payload");
  return incoming.map(normalizeCourse).filter(Boolean);
}

function colorForCourse(course) {
  const key = course.category || course.name || course.id;
  const index = Math.abs(hashCode(key)) % CATEGORY_PALETTE.length;
  const accent = CATEGORY_PALETTE[index];
  return {
    accent,
    background: hexToRgba(accent, 0.12),
  };
}

function hashCode(value) {
  return Array.from(value).reduce((hash, char) => ((hash << 5) - hash + char.charCodeAt(0)) | 0, 0);
}

function hexToRgba(hex, alpha) {
  const clean = hex.replace("#", "");
  const int = parseInt(clean, 16);
  const r = (int >> 16) & 255;
  const g = (int >> 8) & 255;
  const b = int & 255;
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

function createId() {
  if (window.crypto?.randomUUID) return window.crypto.randomUUID();
  return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function cleanText(value, maxLength) {
  return String(value || "").trim().replace(/\s+/g, " ").slice(0, maxLength);
}

function isTime(value) {
  return /^([01]\d|2[0-3]):[0-5]\d$/.test(String(value || ""));
}

function timeToMinutes(value) {
  const [hour, minute] = String(value || "00:00").split(":").map(Number);
  return hour * 60 + minute;
}

function minutesToTimeLabel(value) {
  const hour = Math.floor(value / 60);
  const minute = value % 60;
  return `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
}

function durationLabel(start, end) {
  const duration = timeToMinutes(end) - timeToMinutes(start);
  const hours = Math.floor(duration / 60);
  const minutes = duration % 60;
  if (!hours) return `${minutes} 分钟`;
  if (!minutes) return `${hours} 小时`;
  return `${hours} 小时 ${minutes} 分钟`;
}

function getCourseSessionDates(course) {
  const startDate = parseYmdDate(course.startDate);
  const endDate = parseYmdDate(course.endDate);
  if (!startDate || !endDate || startDate > endDate) return [];
  const dayId = normalizeDay(course.day);
  const targetDay = DAY_INDEX[dayId];
  const excluded = new Set(normalizeDateList(course.excludedDates));
  const first = addDays(startDate, (targetDay - startDate.getDay() + 7) % 7);
  const sessions = [];
  for (let date = first; date <= endDate; date = addDays(date, 7)) {
    const ymd = formatYmdDate(date);
    if (!excluded.has(ymd)) {
      sessions.push({
        date: ymd,
        dayLabel: dayLabel(dayId),
      });
    }
  }
  return sessions;
}

function sessionSummary(course) {
  if (!course.startDate || !course.endDate) return "";
  const total = getCourseSessionDates({ ...course, excludedDates: [] }).length;
  const active = getCourseSessionDates(course).length;
  if (!total) return "0 周";
  return active === total ? `${active} 周` : `${active}/${total} 周`;
}

function normalizeDateInput(value) {
  const text = cleanText(value, 20);
  if (!text) return "";
  const ymd = text.match(/^(\d{4})-(\d{2})-(\d{2})$/u);
  if (ymd && parseYmdDate(text)) return text;
  const slash = text.match(/^(\d{4})[/.](\d{1,2})[/.](\d{1,2})$/u);
  if (slash) {
    const normalized = `${slash[1]}-${slash[2].padStart(2, "0")}-${slash[3].padStart(2, "0")}`;
    return parseYmdDate(normalized) ? normalized : "";
  }
  return "";
}

function normalizeDateList(value) {
  if (Array.isArray(value)) return value.map(normalizeDateInput).filter(Boolean).sort();
  const text = String(value || "").trim();
  if (!text) return [];
  return text.split(/[;；,\n]+/u).map(normalizeDateInput).filter(Boolean).sort();
}

function serializeDateList(value) {
  return normalizeDateList(value).join("; ");
}

function parseYmdDate(value) {
  const match = String(value || "").match(/^(\d{4})-(\d{2})-(\d{2})$/u);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(year, month - 1, day);
  if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) return null;
  return date;
}

function addDays(date, days) {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

function formatYmdDate(date) {
  return [
    date.getFullYear(),
    String(date.getMonth() + 1).padStart(2, "0"),
    String(date.getDate()).padStart(2, "0"),
  ].join("-");
}

function formatDisplayDate(value) {
  const date = parseYmdDate(value);
  if (!date) return value || "";
  return `${date.getMonth() + 1}/${date.getDate()}`;
}

function normalizeClassMode(value) {
  const text = cleanText(value, 20);
  const lower = text.toLowerCase();
  const direct = CLASS_MODES.find((mode) => mode.id === lower || mode.label === text);
  if (direct) return direct.id;
  const aliases = {
    group: "group",
    class: "group",
    "团课": "group",
    "组课": "group",
    "集体课": "group",
    private: "private",
    personal: "private",
    "私课": "private",
    "一对一": "private",
  };
  return aliases[text] || aliases[lower] || "group";
}

function classModeLabel(value) {
  return CLASS_MODES.find((mode) => mode.id === value)?.label || "组课";
}

function classModeShortLabel(value) {
  return value === "private" ? "私" : "组";
}

function priceSummary(course) {
  const parts = [];
  if (course.singlePrice) parts.push(`单期 ${course.singlePrice}`);
  if (course.termPrice) parts.push(`按期 ${course.termPrice}`);
  return parts.join(" · ");
}

function normalizeEnrollments(value) {
  if (Array.isArray(value)) return value.map(normalizeEnrollment).filter(Boolean);
  const text = cleanText(value, 2000);
  if (!text) return [];
  return text.split(/[;；\n]+/u).map((item) => {
    const trimmed = cleanText(item, 120);
    if (!trimmed) return null;
    const pipeParts = trimmed.split("|");
    if (pipeParts.length >= 2) {
      return normalizeEnrollment({ name: pipeParts[0], type: pipeParts.slice(1).join("|") });
    }
    const match = trimmed.match(/^(.+?)[（(](按期|按N次|按n次|N次|n次)[）)]$/u);
    if (match) return normalizeEnrollment({ name: match[1], type: match[2] });
    return normalizeEnrollment({ name: trimmed, type: "term" });
  }).filter(Boolean);
}

function normalizeEnrollment(input) {
  if (!input || typeof input !== "object") return null;
  const name = cleanText(input.name, 40);
  if (!name) return null;
  return {
    name,
    type: normalizeEnrollmentType(input.type),
  };
}

function normalizeEnrollmentType(value) {
  const text = cleanText(value, 20);
  const lower = text.toLowerCase();
  const direct = ENROLLMENT_TYPES.find((type) => type.id === lower || type.label === text);
  if (direct) return direct.id;
  const aliases = {
    term: "term",
    "按期": "term",
    "整期": "term",
    semester: "term",
    passes: "passes",
    pass: "passes",
    n: "passes",
    "n次": "passes",
    "N次": "passes",
    "按n次": "passes",
    "按N次": "passes",
    "次卡": "passes",
  };
  return aliases[text] || aliases[lower] || "term";
}

function enrollmentTypeLabel(value) {
  return ENROLLMENT_TYPES.find((type) => type.id === value)?.label || "按期";
}

function serializeEnrollments(enrollments) {
  return normalizeEnrollments(enrollments).map((enrollment) => {
    return `${enrollment.name}|${enrollmentTypeLabel(enrollment.type)}`;
  }).join("; ");
}

function enrollmentCounts(enrollments) {
  return normalizeEnrollments(enrollments).reduce((counts, enrollment) => {
    counts.total += 1;
    counts[enrollment.type] = (counts[enrollment.type] || 0) + 1;
    return counts;
  }, { total: 0, term: 0, passes: 0 });
}

function enrollmentSummary(enrollments) {
  const counts = enrollmentCounts(enrollments);
  if (!counts.total) return "报名 0 人";
  return `报名 ${counts.total} 人 · 按期 ${counts.term} · 按N次 ${counts.passes}`;
}

function courseHoverText(course) {
  const lines = [
    `${course.name} · ${dayLabel(course.day)} ${course.start}-${course.end}`,
    [
      course.teacher ? `老师 ${course.teacher}` : "未设置老师",
      course.category ? `分类 ${course.category}` : "未分类",
      course.age ? `年龄 ${course.age}` : "",
      roomLabel(course.room),
      classModeLabel(course.classMode),
      priceSummary(course),
      sessionSummary(course),
    ].filter(Boolean).join(" · "),
  ].filter(Boolean);
  const enrollments = normalizeEnrollments(course.enrollments);
  const termNames = enrollments.filter((item) => item.type === "term").map((item) => item.name);
  const passNames = enrollments.filter((item) => item.type === "passes").map((item) => item.name);
  lines.push(termNames.length ? `按期：${termNames.join("、")}` : "按期：无");
  lines.push(passNames.length ? `按N次：${passNames.join("、")}` : "按N次：无");
  return lines.join("\n");
}

function dayOrder(dayId) {
  return DAYS.find((day) => day.id === dayId)?.order || 99;
}

function normalizeDay(value) {
  const text = cleanText(value, 20);
  const lower = text.toLowerCase();
  const direct = DAYS.find((day) => day.id === lower || day.label === text);
  if (direct) return direct.id;
  const aliases = {
    monday: "mon",
    tuesday: "tue",
    wednesday: "wed",
    thursday: "thu",
    friday: "fri",
    saturday: "sat",
    sunday: "sun",
    "星期一": "mon",
    "星期二": "tue",
    "星期三": "wed",
    "星期四": "thu",
    "星期五": "fri",
    "星期六": "sat",
    "星期日": "sun",
    "星期天": "sun",
    "周1": "mon",
    "周2": "tue",
    "周3": "wed",
    "周4": "thu",
    "周5": "fri",
    "周6": "sat",
    "周7": "sun",
  };
  return aliases[text] || aliases[lower] || "mon";
}

function dayLabel(dayId) {
  return DAYS.find((day) => day.id === dayId)?.label || dayId || "";
}

function normalizeRoom(value) {
  const text = cleanText(value, 20);
  const lower = text.toLowerCase();
  const direct = ROOMS.find((room) => room.id === lower || room.label === text);
  if (direct) return direct.id;
  const aliases = {
    "大": "large",
    "大房": "large",
    "大教室": "large",
    large: "large",
    big: "large",
    "小": "small",
    "小房": "small",
    "小教室": "small",
    small: "small",
  };
  return aliases[text] || aliases[lower] || "large";
}

function roomLabel(roomId) {
  return ROOMS.find((room) => room.id === roomId)?.label || roomId || "";
}
