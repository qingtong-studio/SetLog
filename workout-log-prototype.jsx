import { useState, useEffect, useCallback, useRef } from "react";

const SCREENS = {
  TEMPLATES: "templates",
  CREATE_TEMPLATE: "create_template",
  EDIT_TEMPLATE: "edit_template",
  WORKOUT: "workout",
  HISTORY: "history",
  WORKOUT_DETAIL: "workout_detail",
  SETTINGS: "settings",
  SUMMARY: "summary",
};

const MUSCLE_GROUPS = ["胸", "背", "肩", "腿", "臂", "核心", "全身"];

// ─── Mock Data ───
const defaultTemplates = [
  {
    id: 1,
    name: "胸部训练日",
    tags: ["胸", "臂"],
    exercises: [
      { id: 1, name: "杠铃卧推", sets: 4, reps: 8, weight: 60, rest: 90 },
      { id: 2, name: "哑铃飞鸟", sets: 3, reps: 12, weight: 14, rest: 60 },
      { id: 3, name: "上斜哑铃卧推", sets: 3, reps: 10, weight: 20, rest: 90 },
      { id: 4, name: "绳索夹胸", sets: 3, reps: 15, weight: 15, rest: 60 },
    ],
  },
  {
    id: 2,
    name: "腿部力量日",
    tags: ["腿", "核心"],
    exercises: [
      { id: 1, name: "深蹲", sets: 5, reps: 5, weight: 80, rest: 120 },
      { id: 2, name: "罗马尼亚硬拉", sets: 4, reps: 8, weight: 60, rest: 90 },
      { id: 3, name: "腿举", sets: 3, reps: 12, weight: 120, rest: 90 },
      { id: 4, name: "腿弯举", sets: 3, reps: 12, weight: 30, rest: 60 },
    ],
  },
  {
    id: 3,
    name: "背部 & 二头",
    tags: ["背", "臂"],
    exercises: [
      { id: 1, name: "引体向上", sets: 4, reps: 8, weight: 0, rest: 90 },
      { id: 2, name: "杠铃划船", sets: 4, reps: 8, weight: 50, rest: 90 },
      { id: 3, name: "哑铃弯举", sets: 3, reps: 12, weight: 12, rest: 60 },
    ],
  },
];

const defaultHistory = [
  {
    id: 1,
    templateName: "胸部训练日",
    date: "2026-04-02",
    duration: 52,
    totalSets: 13,
    totalVolume: 4860,
    exercises: [
      { name: "杠铃卧推", sets: [
        { weight: 60, reps: 8, rest: 92 },
        { weight: 60, reps: 8, rest: 88 },
        { weight: 65, reps: 6, rest: 95 },
        { weight: 55, reps: 10, rest: 0 },
      ]},
      { name: "哑铃飞鸟", sets: [
        { weight: 14, reps: 12, rest: 62 },
        { weight: 14, reps: 12, rest: 58 },
        { weight: 14, reps: 10, rest: 0 },
      ]},
      { name: "上斜哑铃卧推", sets: [
        { weight: 20, reps: 10, rest: 90 },
        { weight: 20, reps: 9, rest: 85 },
        { weight: 20, reps: 8, rest: 0 },
      ]},
      { name: "绳索夹胸", sets: [
        { weight: 15, reps: 15, rest: 60 },
        { weight: 15, reps: 14, rest: 55 },
        { weight: 15, reps: 12, rest: 0 },
      ]},
    ],
  },
  {
    id: 2,
    templateName: "腿部力量日",
    date: "2026-04-01",
    duration: 65,
    totalSets: 15,
    totalVolume: 7200,
    exercises: [
      { name: "深蹲", sets: [
        { weight: 80, reps: 5, rest: 120 },
        { weight: 80, reps: 5, rest: 118 },
        { weight: 85, reps: 4, rest: 125 },
        { weight: 80, reps: 5, rest: 120 },
        { weight: 75, reps: 6, rest: 0 },
      ]},
      { name: "罗马尼亚硬拉", sets: [
        { weight: 60, reps: 8, rest: 90 },
        { weight: 60, reps: 8, rest: 92 },
        { weight: 60, reps: 8, rest: 88 },
        { weight: 60, reps: 7, rest: 0 },
      ]},
      { name: "腿举", sets: [
        { weight: 120, reps: 12, rest: 90 },
        { weight: 120, reps: 11, rest: 85 },
        { weight: 120, reps: 10, rest: 0 },
      ]},
      { name: "腿弯举", sets: [
        { weight: 30, reps: 12, rest: 60 },
        { weight: 30, reps: 12, rest: 58 },
        { weight: 30, reps: 10, rest: 0 },
      ]},
    ],
  },
  {
    id: 3,
    templateName: "背部 & 二头",
    date: "2026-03-30",
    duration: 45,
    totalSets: 11,
    totalVolume: 3480,
    exercises: [
      { name: "引体向上", sets: [
        { weight: 0, reps: 8, rest: 90 },
        { weight: 0, reps: 7, rest: 95 },
        { weight: 0, reps: 6, rest: 88 },
        { weight: 0, reps: 6, rest: 0 },
      ]},
      { name: "杠铃划船", sets: [
        { weight: 50, reps: 8, rest: 90 },
        { weight: 50, reps: 8, rest: 92 },
        { weight: 55, reps: 6, rest: 88 },
        { weight: 50, reps: 8, rest: 0 },
      ]},
      { name: "哑铃弯举", sets: [
        { weight: 12, reps: 12, rest: 60 },
        { weight: 12, reps: 11, rest: 58 },
        { weight: 12, reps: 10, rest: 0 },
      ]},
    ],
  },
  {
    id: 4,
    templateName: "胸部训练日",
    date: "2026-03-28",
    duration: 48,
    totalSets: 13,
    totalVolume: 4650,
    exercises: [],
  },
  {
    id: 5,
    templateName: "腿部力量日",
    date: "2026-03-26",
    duration: 60,
    totalSets: 15,
    totalVolume: 6900,
    exercises: [],
  },
];

// ─── Icons (inline SVG) ───
const Icons = {
  Dumbbell: () => (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M6.5 6.5h11M6.5 17.5h11M3 10h2v4H3zM19 10h2v4h-2zM5 8h2v8H5zM17 8h2v8h-2zM7 11h10v2H7z"/>
    </svg>
  ),
  Calendar: () => (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>
    </svg>
  ),
  Settings: () => (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>
    </svg>
  ),
  Plus: () => (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
  ),
  Play: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg>
  ),
  Edit: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
  ),
  Check: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
  ),
  ChevronLeft: () => (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
  ),
  ChevronRight: () => (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
  ),
  Clock: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
  ),
  Trash: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
  ),
  Skip: () => (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><polygon points="5 4 15 12 5 20 5 4"/><line x1="19" y1="5" x2="19" y2="19"/></svg>
  ),
  Fire: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z"/></svg>
  ),
  X: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
  ),
};

// ─── Helpers ───
const formatTime = (s) => {
  const m = Math.floor(s / 60);
  const sec = s % 60;
  return `${m.toString().padStart(2, "0")}:${sec.toString().padStart(2, "0")}`;
};

const getDaysInMonth = (year, month) => new Date(year, month + 1, 0).getDate();
const getFirstDayOfMonth = (year, month) => new Date(year, month, 1).getDay();

// ─── Style Constants ───
const theme = {
  bg: "#0a0a0b",
  surface: "#141416",
  surfaceHover: "#1c1c1f",
  border: "#2a2a2e",
  accent: "#e8ff47",
  accentDim: "rgba(232,255,71,0.12)",
  accentText: "#0a0a0b",
  text: "#e8e8ec",
  textSecondary: "#8a8a92",
  textTertiary: "#5a5a62",
  danger: "#ff4757",
  dangerDim: "rgba(255,71,87,0.12)",
  success: "#2ed573",
  successDim: "rgba(46,213,115,0.12)",
  radius: "14px",
  radiusSm: "10px",
  font: "'DM Sans', 'Noto Sans SC', sans-serif",
  fontMono: "'JetBrains Mono', 'SF Mono', monospace",
};

// ─── Main App ───
export default function WorkoutApp() {
  const [screen, setScreen] = useState(SCREENS.TEMPLATES);
  const [templates, setTemplates] = useState(defaultTemplates);
  const [history, setHistory] = useState(defaultHistory);
  const [settings, setSettings] = useState({
    unit: "kg",
    defaultRest: 90,
    timerSound: true,
    timerVibrate: true,
    darkMode: true,
  });
  const [activeTemplate, setActiveTemplate] = useState(null);
  const [editingTemplate, setEditingTemplate] = useState(null);
  const [viewingWorkout, setViewingWorkout] = useState(null);
  const [workoutSession, setWorkoutSession] = useState(null);
  const [prevScreen, setPrevScreen] = useState(null);

  const navigate = (s, data) => {
    setPrevScreen(screen);
    setScreen(s);
  };

  const goBack = () => {
    if (prevScreen) {
      setScreen(prevScreen);
      setPrevScreen(null);
    }
  };

  return (
    <div style={{
      fontFamily: theme.font,
      background: theme.bg,
      color: theme.text,
      minHeight: "100vh",
      maxWidth: "430px",
      margin: "0 auto",
      position: "relative",
      overflow: "hidden",
    }}>
      <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&family=Noto+Sans+SC:wght@400;500;600;700&display=swap" rel="stylesheet" />

      <div style={{ paddingBottom: "80px" }}>
        {screen === SCREENS.TEMPLATES && (
          <TemplatesScreen
            templates={templates}
            onEdit={(t) => { setEditingTemplate({...t, exercises: t.exercises.map(e => ({...e}))}); navigate(SCREENS.EDIT_TEMPLATE); }}
            onStart={(t) => {
              setActiveTemplate(t);
              setWorkoutSession({
                templateName: t.name,
                startTime: Date.now(),
                exercises: t.exercises.map(e => ({
                  name: e.name,
                  targetSets: e.sets,
                  targetReps: e.reps,
                  targetWeight: e.weight,
                  rest: e.rest,
                  sets: Array.from({ length: e.sets }, () => ({
                    weight: e.weight,
                    reps: e.reps,
                    rest: 0,
                    completed: false,
                  })),
                })),
                currentExercise: 0,
                currentSet: 0,
              });
              navigate(SCREENS.WORKOUT);
            }}
            onCreate={() => {
              setEditingTemplate({ id: Date.now(), name: "", tags: [], exercises: [] });
              navigate(SCREENS.CREATE_TEMPLATE);
            }}
            unit={settings.unit}
          />
        )}
        {screen === SCREENS.CREATE_TEMPLATE && (
          <TemplateEditor
            template={editingTemplate}
            isNew={true}
            onSave={(t) => { setTemplates([...templates, t]); navigate(SCREENS.TEMPLATES); }}
            onCancel={() => navigate(SCREENS.TEMPLATES)}
            unit={settings.unit}
          />
        )}
        {screen === SCREENS.EDIT_TEMPLATE && (
          <TemplateEditor
            template={editingTemplate}
            isNew={false}
            onSave={(t) => { setTemplates(templates.map(x => x.id === t.id ? t : x)); navigate(SCREENS.TEMPLATES); }}
            onDelete={(id) => { setTemplates(templates.filter(x => x.id !== id)); navigate(SCREENS.TEMPLATES); }}
            onCancel={() => navigate(SCREENS.TEMPLATES)}
            unit={settings.unit}
          />
        )}
        {screen === SCREENS.WORKOUT && workoutSession && (
          <WorkoutScreen
            session={workoutSession}
            setSession={setWorkoutSession}
            unit={settings.unit}
            defaultRest={settings.defaultRest}
            onFinish={(result) => {
              const dur = Math.round((Date.now() - workoutSession.startTime) / 60000);
              let totalSets = 0;
              let totalVol = 0;
              result.exercises.forEach(e => {
                e.sets.forEach(s => {
                  if (s.completed) {
                    totalSets++;
                    totalVol += s.weight * s.reps;
                  }
                });
              });
              const record = {
                id: Date.now(),
                templateName: result.templateName,
                date: new Date().toISOString().split("T")[0],
                duration: dur,
                totalSets,
                totalVolume: totalVol,
                exercises: result.exercises.map(e => ({
                  name: e.name,
                  sets: e.sets.filter(s => s.completed).map(s => ({
                    weight: s.weight,
                    reps: s.reps,
                    rest: s.rest,
                  })),
                })),
              };
              setHistory([record, ...history]);
              setViewingWorkout(record);
              navigate(SCREENS.SUMMARY);
            }}
            onCancel={() => navigate(SCREENS.TEMPLATES)}
          />
        )}
        {screen === SCREENS.SUMMARY && viewingWorkout && (
          <SummaryScreen
            workout={viewingWorkout}
            unit={settings.unit}
            onDone={() => navigate(SCREENS.TEMPLATES)}
          />
        )}
        {screen === SCREENS.HISTORY && (
          <HistoryScreen
            history={history}
            unit={settings.unit}
            onSelect={(w) => { setViewingWorkout(w); navigate(SCREENS.WORKOUT_DETAIL); }}
          />
        )}
        {screen === SCREENS.WORKOUT_DETAIL && viewingWorkout && (
          <WorkoutDetailScreen
            workout={viewingWorkout}
            unit={settings.unit}
            onBack={() => navigate(SCREENS.HISTORY)}
          />
        )}
        {screen === SCREENS.SETTINGS && (
          <SettingsScreen settings={settings} setSettings={setSettings} />
        )}
      </div>

      {/* Bottom Tab Bar */}
      {screen !== SCREENS.WORKOUT && (
        <div style={{
          position: "fixed",
          bottom: 0,
          left: "50%",
          transform: "translateX(-50%)",
          width: "100%",
          maxWidth: "430px",
          background: "rgba(10,10,11,0.92)",
          backdropFilter: "blur(20px)",
          borderTop: `1px solid ${theme.border}`,
          display: "flex",
          justifyContent: "space-around",
          padding: "8px 0 20px",
          zIndex: 100,
        }}>
          {[
            { id: SCREENS.TEMPLATES, icon: Icons.Dumbbell, label: "训练" },
            { id: SCREENS.HISTORY, icon: Icons.Calendar, label: "记录" },
            { id: SCREENS.SETTINGS, icon: Icons.Settings, label: "设置" },
          ].map(tab => (
            <button
              key={tab.id}
              onClick={() => navigate(tab.id)}
              style={{
                background: "none",
                border: "none",
                color: screen === tab.id || (screen === SCREENS.WORKOUT_DETAIL && tab.id === SCREENS.HISTORY) ? theme.accent : theme.textTertiary,
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                gap: "4px",
                cursor: "pointer",
                padding: "4px 16px",
                transition: "color 0.2s",
              }}
            >
              <tab.icon />
              <span style={{ fontSize: "11px", fontWeight: 500 }}>{tab.label}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════
// SCREEN: Templates List
// ═══════════════════════════════════════════════
function TemplatesScreen({ templates, onEdit, onStart, onCreate, unit }) {
  return (
    <div style={{ padding: "16px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "24px", paddingTop: "8px" }}>
        <div>
          <h1 style={{ fontSize: "28px", fontWeight: 700, margin: 0, letterSpacing: "-0.5px" }}>训练计划</h1>
          <p style={{ margin: "4px 0 0", color: theme.textSecondary, fontSize: "14px" }}>选择模板开始训练</p>
        </div>
        <button
          onClick={onCreate}
          style={{
            background: theme.accent,
            color: theme.accentText,
            border: "none",
            borderRadius: "50%",
            width: "44px",
            height: "44px",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            cursor: "pointer",
            boxShadow: `0 0 20px ${theme.accentDim}`,
          }}
        >
          <Icons.Plus />
        </button>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
        {templates.map(t => (
          <div key={t.id} style={{
            background: theme.surface,
            borderRadius: theme.radius,
            border: `1px solid ${theme.border}`,
            overflow: "hidden",
          }}>
            <div style={{ padding: "16px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "10px" }}>
                <div>
                  <h3 style={{ margin: 0, fontSize: "17px", fontWeight: 600 }}>{t.name}</h3>
                  <div style={{ display: "flex", gap: "6px", marginTop: "8px", flexWrap: "wrap" }}>
                    {t.tags.map(tag => (
                      <span key={tag} style={{
                        fontSize: "11px",
                        fontWeight: 600,
                        padding: "3px 8px",
                        borderRadius: "6px",
                        background: theme.accentDim,
                        color: theme.accent,
                        letterSpacing: "0.3px",
                      }}>{tag}</span>
                    ))}
                  </div>
                </div>
                <button onClick={() => onEdit(t)} style={{
                  background: "none",
                  border: "none",
                  color: theme.textSecondary,
                  cursor: "pointer",
                  padding: "4px",
                }}>
                  <Icons.Edit />
                </button>
              </div>

              <div style={{ display: "flex", flexDirection: "column", gap: "6px", marginTop: "12px" }}>
                {t.exercises.map((e, i) => (
                  <div key={i} style={{
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                    fontSize: "13px",
                    color: theme.textSecondary,
                    padding: "4px 0",
                  }}>
                    <span style={{ color: theme.text, fontWeight: 500 }}>{e.name}</span>
                    <span style={{ fontFamily: theme.fontMono, fontSize: "12px" }}>
                      {e.sets}×{e.reps} · {e.weight}{unit}
                    </span>
                  </div>
                ))}
              </div>
            </div>

            <button
              onClick={() => onStart(t)}
              style={{
                width: "100%",
                padding: "13px",
                background: theme.accentDim,
                color: theme.accent,
                border: "none",
                borderTop: `1px solid ${theme.border}`,
                fontSize: "14px",
                fontWeight: 600,
                cursor: "pointer",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                gap: "8px",
                letterSpacing: "0.3px",
              }}
            >
              <Icons.Play /> 开始训练
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════
// SCREEN: Template Editor (Create / Edit)
// ═══════════════════════════════════════════════
function TemplateEditor({ template, isNew, onSave, onDelete, onCancel, unit }) {
  const [data, setData] = useState(template);

  const addExercise = () => {
    setData({
      ...data,
      exercises: [...data.exercises, { id: Date.now(), name: "", sets: 3, reps: 10, weight: 20, rest: 90 }],
    });
  };

  const updateExercise = (idx, field, val) => {
    const exs = [...data.exercises];
    exs[idx] = { ...exs[idx], [field]: val };
    setData({ ...data, exercises: exs });
  };

  const removeExercise = (idx) => {
    setData({ ...data, exercises: data.exercises.filter((_, i) => i !== idx) });
  };

  const toggleTag = (tag) => {
    const tags = data.tags.includes(tag)
      ? data.tags.filter(t => t !== tag)
      : [...data.tags, tag];
    setData({ ...data, tags });
  };

  return (
    <div style={{ padding: "16px" }}>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "24px", paddingTop: "8px" }}>
        <button onClick={onCancel} style={{ background: "none", border: "none", color: theme.textSecondary, cursor: "pointer", display: "flex", alignItems: "center", gap: "4px", fontSize: "14px" }}>
          <Icons.ChevronLeft /> 返回
        </button>
        <h2 style={{ margin: 0, fontSize: "18px", fontWeight: 600 }}>{isNew ? "新建模板" : "编辑模板"}</h2>
        <button onClick={() => onSave(data)} style={{
          background: theme.accent,
          color: theme.accentText,
          border: "none",
          borderRadius: theme.radiusSm,
          padding: "8px 16px",
          fontSize: "13px",
          fontWeight: 600,
          cursor: "pointer",
        }}>保存</button>
      </div>

      {/* Name */}
      <div style={{ marginBottom: "20px" }}>
        <label style={{ fontSize: "12px", fontWeight: 600, color: theme.textSecondary, textTransform: "uppercase", letterSpacing: "0.5px", display: "block", marginBottom: "8px" }}>模板名称</label>
        <input
          value={data.name}
          onChange={e => setData({ ...data, name: e.target.value })}
          placeholder="例如：胸部训练日"
          style={{
            width: "100%",
            padding: "12px 14px",
            background: theme.surface,
            border: `1px solid ${theme.border}`,
            borderRadius: theme.radiusSm,
            color: theme.text,
            fontSize: "15px",
            outline: "none",
            boxSizing: "border-box",
            fontFamily: theme.font,
          }}
        />
      </div>

      {/* Tags */}
      <div style={{ marginBottom: "24px" }}>
        <label style={{ fontSize: "12px", fontWeight: 600, color: theme.textSecondary, textTransform: "uppercase", letterSpacing: "0.5px", display: "block", marginBottom: "8px" }}>目标肌群</label>
        <div style={{ display: "flex", flexWrap: "wrap", gap: "8px" }}>
          {MUSCLE_GROUPS.map(g => (
            <button key={g} onClick={() => toggleTag(g)} style={{
              padding: "6px 14px",
              borderRadius: "20px",
              border: `1px solid ${data.tags.includes(g) ? theme.accent : theme.border}`,
              background: data.tags.includes(g) ? theme.accentDim : "transparent",
              color: data.tags.includes(g) ? theme.accent : theme.textSecondary,
              fontSize: "13px",
              fontWeight: 500,
              cursor: "pointer",
            }}>
              {g}
            </button>
          ))}
        </div>
      </div>

      {/* Exercises */}
      <div>
        <label style={{ fontSize: "12px", fontWeight: 600, color: theme.textSecondary, textTransform: "uppercase", letterSpacing: "0.5px", display: "block", marginBottom: "12px" }}>训练动作</label>
        <div style={{ display: "flex", flexDirection: "column", gap: "10px" }}>
          {data.exercises.map((ex, idx) => (
            <div key={ex.id} style={{
              background: theme.surface,
              border: `1px solid ${theme.border}`,
              borderRadius: theme.radiusSm,
              padding: "14px",
            }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "10px" }}>
                <input
                  value={ex.name}
                  onChange={e => updateExercise(idx, "name", e.target.value)}
                  placeholder="动作名称"
                  style={{
                    background: "none",
                    border: "none",
                    color: theme.text,
                    fontSize: "15px",
                    fontWeight: 600,
                    outline: "none",
                    flex: 1,
                    fontFamily: theme.font,
                  }}
                />
                <button onClick={() => removeExercise(idx)} style={{ background: "none", border: "none", color: theme.danger, cursor: "pointer", padding: "4px" }}>
                  <Icons.Trash />
                </button>
              </div>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr 1fr", gap: "8px" }}>
                {[
                  { label: "组数", field: "sets", val: ex.sets },
                  { label: "次数", field: "reps", val: ex.reps },
                  { label: `重量(${unit})`, field: "weight", val: ex.weight },
                  { label: "休息(秒)", field: "rest", val: ex.rest },
                ].map(f => (
                  <div key={f.field}>
                    <div style={{ fontSize: "10px", color: theme.textTertiary, marginBottom: "4px", textAlign: "center" }}>{f.label}</div>
                    <input
                      type="number"
                      value={f.val}
                      onChange={e => updateExercise(idx, f.field, parseInt(e.target.value) || 0)}
                      style={{
                        width: "100%",
                        padding: "8px 4px",
                        background: theme.bg,
                        border: `1px solid ${theme.border}`,
                        borderRadius: "8px",
                        color: theme.text,
                        fontSize: "14px",
                        fontFamily: theme.fontMono,
                        textAlign: "center",
                        outline: "none",
                        boxSizing: "border-box",
                      }}
                    />
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>

        <button onClick={addExercise} style={{
          width: "100%",
          padding: "14px",
          marginTop: "12px",
          background: "transparent",
          border: `1px dashed ${theme.border}`,
          borderRadius: theme.radiusSm,
          color: theme.textSecondary,
          fontSize: "14px",
          cursor: "pointer",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: "6px",
        }}>
          <Icons.Plus /> 添加动作
        </button>
      </div>

      {!isNew && onDelete && (
        <button onClick={() => onDelete(data.id)} style={{
          width: "100%",
          padding: "14px",
          marginTop: "24px",
          background: theme.dangerDim,
          border: "none",
          borderRadius: theme.radiusSm,
          color: theme.danger,
          fontSize: "14px",
          fontWeight: 600,
          cursor: "pointer",
        }}>
          删除模板
        </button>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════
// SCREEN: Active Workout
// ═══════════════════════════════════════════════
function WorkoutScreen({ session, setSession, unit, defaultRest, onFinish, onCancel }) {
  const [showTimer, setShowTimer] = useState(false);
  const [timerDuration, setTimerDuration] = useState(0);
  const [timerElapsed, setTimerElapsed] = useState(0);
  const [completedSetInfo, setCompletedSetInfo] = useState(null);
  const timerRef = useRef(null);

  const currentEx = session.exercises[session.currentExercise];

  const startTimer = (restSeconds, exIdx, setIdx) => {
    setTimerDuration(restSeconds);
    setTimerElapsed(0);
    setCompletedSetInfo({ exIdx, setIdx });
    setShowTimer(true);

    if (timerRef.current) clearInterval(timerRef.current);
    timerRef.current = setInterval(() => {
      setTimerElapsed(prev => {
        if (prev + 1 >= restSeconds) {
          clearInterval(timerRef.current);
          return restSeconds;
        }
        return prev + 1;
      });
    }, 1000);
  };

  const skipTimer = () => {
    clearInterval(timerRef.current);
    if (completedSetInfo) {
      const exs = [...session.exercises];
      exs[completedSetInfo.exIdx].sets[completedSetInfo.setIdx].rest = timerElapsed;
      setSession({ ...session, exercises: exs });
    }
    setShowTimer(false);
  };

  const timerDone = () => {
    if (completedSetInfo) {
      const exs = [...session.exercises];
      exs[completedSetInfo.exIdx].sets[completedSetInfo.setIdx].rest = timerDuration;
      setSession({ ...session, exercises: exs });
    }
    setShowTimer(false);
  };

  const completeSet = (exIdx, setIdx) => {
    const exs = [...session.exercises];
    exs[exIdx].sets[setIdx].completed = true;
    setSession({ ...session, exercises: exs });

    const isLastSet = setIdx === exs[exIdx].sets.length - 1;
    const isLastExercise = exIdx === exs.length - 1;
    if (!(isLastSet && isLastExercise)) {
      startTimer(exs[exIdx].rest || defaultRest, exIdx, setIdx);
    }
  };

  const updateSet = (exIdx, setIdx, field, val) => {
    const exs = [...session.exercises];
    exs[exIdx].sets[setIdx][field] = val;
    setSession({ ...session, exercises: exs });
  };

  const addSet = (exIdx) => {
    const exs = [...session.exercises];
    const lastSet = exs[exIdx].sets[exs[exIdx].sets.length - 1];
    exs[exIdx].sets.push({ weight: lastSet.weight, reps: lastSet.reps, rest: 0, completed: false });
    setSession({ ...session, exercises: exs });
  };

  const completedCount = session.exercises.reduce((sum, e) => sum + e.sets.filter(s => s.completed).length, 0);
  const totalCount = session.exercises.reduce((sum, e) => sum + e.sets.length, 0);
  const progress = totalCount > 0 ? completedCount / totalCount : 0;

  const elapsedMin = Math.round((Date.now() - session.startTime) / 60000);

  return (
    <div style={{ padding: "16px", position: "relative" }}>
      {/* Header */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "16px", paddingTop: "8px" }}>
        <div>
          <h2 style={{ margin: 0, fontSize: "20px", fontWeight: 700 }}>{session.templateName}</h2>
          <div style={{ display: "flex", gap: "12px", marginTop: "4px", fontSize: "13px", color: theme.textSecondary }}>
            <span style={{ display: "flex", alignItems: "center", gap: "4px" }}><Icons.Clock /> {elapsedMin} 分钟</span>
            <span>{completedCount}/{totalCount} 组</span>
          </div>
        </div>
        <div style={{ display: "flex", gap: "8px" }}>
          <button onClick={onCancel} style={{ background: theme.dangerDim, color: theme.danger, border: "none", borderRadius: theme.radiusSm, padding: "8px 14px", fontSize: "13px", fontWeight: 600, cursor: "pointer" }}>放弃</button>
          <button onClick={() => onFinish(session)} style={{ background: theme.accent, color: theme.accentText, border: "none", borderRadius: theme.radiusSm, padding: "8px 14px", fontSize: "13px", fontWeight: 600, cursor: "pointer" }}>完成</button>
        </div>
      </div>

      {/* Progress bar */}
      <div style={{ height: "4px", background: theme.border, borderRadius: "2px", marginBottom: "20px", overflow: "hidden" }}>
        <div style={{ height: "100%", width: `${progress * 100}%`, background: theme.accent, borderRadius: "2px", transition: "width 0.4s ease" }} />
      </div>

      {/* Exercises */}
      <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
        {session.exercises.map((ex, exIdx) => (
          <div key={exIdx} style={{
            background: theme.surface,
            borderRadius: theme.radius,
            border: `1px solid ${theme.border}`,
            padding: "16px",
          }}>
            <h3 style={{ margin: "0 0 12px", fontSize: "16px", fontWeight: 600 }}>{ex.name}</h3>

            {/* Column headers */}
            <div style={{
              display: "grid",
              gridTemplateColumns: "40px 1fr 1fr 50px",
              gap: "8px",
              marginBottom: "6px",
              fontSize: "11px",
              color: theme.textTertiary,
              textTransform: "uppercase",
              letterSpacing: "0.5px",
              fontWeight: 600,
            }}>
              <div>组</div>
              <div style={{ textAlign: "center" }}>重量({unit})</div>
              <div style={{ textAlign: "center" }}>次数</div>
              <div style={{ textAlign: "center" }}>✓</div>
            </div>

            {ex.sets.map((set, setIdx) => (
              <div key={setIdx} style={{
                display: "grid",
                gridTemplateColumns: "40px 1fr 1fr 50px",
                gap: "8px",
                alignItems: "center",
                padding: "6px 0",
                opacity: set.completed ? 0.5 : 1,
              }}>
                <div style={{
                  fontSize: "13px",
                  fontFamily: theme.fontMono,
                  color: theme.textSecondary,
                  fontWeight: 500,
                }}>{setIdx + 1}</div>
                <input
                  type="number"
                  value={set.weight}
                  onChange={e => updateSet(exIdx, setIdx, "weight", parseFloat(e.target.value) || 0)}
                  disabled={set.completed}
                  style={{
                    padding: "8px",
                    background: set.completed ? theme.successDim : theme.bg,
                    border: `1px solid ${set.completed ? "transparent" : theme.border}`,
                    borderRadius: "8px",
                    color: theme.text,
                    fontSize: "14px",
                    fontFamily: theme.fontMono,
                    textAlign: "center",
                    outline: "none",
                    width: "100%",
                    boxSizing: "border-box",
                  }}
                />
                <input
                  type="number"
                  value={set.reps}
                  onChange={e => updateSet(exIdx, setIdx, "reps", parseInt(e.target.value) || 0)}
                  disabled={set.completed}
                  style={{
                    padding: "8px",
                    background: set.completed ? theme.successDim : theme.bg,
                    border: `1px solid ${set.completed ? "transparent" : theme.border}`,
                    borderRadius: "8px",
                    color: theme.text,
                    fontSize: "14px",
                    fontFamily: theme.fontMono,
                    textAlign: "center",
                    outline: "none",
                    width: "100%",
                    boxSizing: "border-box",
                  }}
                />
                <button
                  onClick={() => !set.completed && completeSet(exIdx, setIdx)}
                  disabled={set.completed}
                  style={{
                    width: "40px",
                    height: "40px",
                    borderRadius: "10px",
                    border: set.completed ? "none" : `2px solid ${theme.border}`,
                    background: set.completed ? theme.success : "transparent",
                    color: set.completed ? "#fff" : theme.textTertiary,
                    cursor: set.completed ? "default" : "pointer",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    margin: "0 auto",
                    transition: "all 0.2s",
                  }}
                >
                  <Icons.Check />
                </button>
              </div>
            ))}

            <button onClick={() => addSet(exIdx)} style={{
              width: "100%",
              padding: "8px",
              marginTop: "8px",
              background: "transparent",
              border: `1px dashed ${theme.border}`,
              borderRadius: "8px",
              color: theme.textTertiary,
              fontSize: "12px",
              cursor: "pointer",
            }}>+ 添加一组</button>
          </div>
        ))}
      </div>

      {/* Rest Timer Overlay */}
      {showTimer && (
        <div style={{
          position: "fixed",
          inset: 0,
          background: "rgba(0,0,0,0.85)",
          backdropFilter: "blur(20px)",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          zIndex: 1000,
        }}>
          <p style={{ color: theme.textSecondary, fontSize: "14px", fontWeight: 500, marginBottom: "8px", letterSpacing: "2px", textTransform: "uppercase" }}>组间休息</p>

          {/* Circular timer */}
          <div style={{ position: "relative", width: "200px", height: "200px", marginBottom: "32px" }}>
            <svg width="200" height="200" style={{ transform: "rotate(-90deg)" }}>
              <circle cx="100" cy="100" r="90" fill="none" stroke={theme.border} strokeWidth="6" />
              <circle
                cx="100" cy="100" r="90" fill="none"
                stroke={timerElapsed >= timerDuration ? theme.success : theme.accent}
                strokeWidth="6"
                strokeDasharray={`${2 * Math.PI * 90}`}
                strokeDashoffset={`${2 * Math.PI * 90 * (1 - timerElapsed / timerDuration)}`}
                strokeLinecap="round"
                style={{ transition: "stroke-dashoffset 1s linear" }}
              />
            </svg>
            <div style={{
              position: "absolute",
              inset: 0,
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              justifyContent: "center",
            }}>
              <span style={{
                fontSize: "48px",
                fontFamily: theme.fontMono,
                fontWeight: 700,
                color: timerElapsed >= timerDuration ? theme.success : theme.text,
              }}>
                {formatTime(Math.max(0, timerDuration - timerElapsed))}
              </span>
              <span style={{ fontSize: "13px", color: theme.textSecondary, marginTop: "4px" }}>
                已计时 {formatTime(timerElapsed)}
              </span>
            </div>
          </div>

          <div style={{ display: "flex", gap: "12px" }}>
            <button onClick={skipTimer} style={{
              padding: "14px 32px",
              background: theme.surface,
              border: `1px solid ${theme.border}`,
              borderRadius: theme.radiusSm,
              color: theme.text,
              fontSize: "15px",
              fontWeight: 600,
              cursor: "pointer",
              display: "flex",
              alignItems: "center",
              gap: "8px",
            }}>
              <Icons.Skip /> 跳过
            </button>
            {timerElapsed >= timerDuration && (
              <button onClick={timerDone} style={{
                padding: "14px 32px",
                background: theme.accent,
                border: "none",
                borderRadius: theme.radiusSm,
                color: theme.accentText,
                fontSize: "15px",
                fontWeight: 600,
                cursor: "pointer",
              }}>
                继续训练
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════
// SCREEN: Summary
// ═══════════════════════════════════════════════
function SummaryScreen({ workout, unit, onDone }) {
  return (
    <div style={{ padding: "16px", textAlign: "center" }}>
      <div style={{ paddingTop: "40px", marginBottom: "32px" }}>
        <div style={{
          width: "80px",
          height: "80px",
          borderRadius: "50%",
          background: theme.accentDim,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          margin: "0 auto 20px",
          fontSize: "36px",
        }}>
          <Icons.Fire />
        </div>
        <h1 style={{ fontSize: "28px", fontWeight: 700, margin: "0 0 4px" }}>训练完成!</h1>
        <p style={{ color: theme.textSecondary, fontSize: "15px", margin: 0 }}>{workout.templateName}</p>
      </div>

      <div style={{
        display: "grid",
        gridTemplateColumns: "1fr 1fr 1fr",
        gap: "12px",
        marginBottom: "32px",
      }}>
        {[
          { label: "时长", value: `${workout.duration}`, suffix: "分钟" },
          { label: "总组数", value: `${workout.totalSets}`, suffix: "组" },
          { label: "总容量", value: `${Math.round(workout.totalVolume)}`, suffix: unit },
        ].map(s => (
          <div key={s.label} style={{
            background: theme.surface,
            borderRadius: theme.radiusSm,
            padding: "16px 8px",
            border: `1px solid ${theme.border}`,
          }}>
            <div style={{ fontSize: "24px", fontFamily: theme.fontMono, fontWeight: 700, color: theme.accent }}>{s.value}</div>
            <div style={{ fontSize: "11px", color: theme.textSecondary, marginTop: "4px" }}>{s.suffix}</div>
            <div style={{ fontSize: "11px", color: theme.textTertiary, marginTop: "2px" }}>{s.label}</div>
          </div>
        ))}
      </div>

      {/* Exercise breakdown */}
      <div style={{ textAlign: "left" }}>
        {workout.exercises.map((ex, i) => (
          <div key={i} style={{
            background: theme.surface,
            borderRadius: theme.radiusSm,
            border: `1px solid ${theme.border}`,
            padding: "14px",
            marginBottom: "8px",
          }}>
            <h4 style={{ margin: "0 0 8px", fontSize: "14px", fontWeight: 600 }}>{ex.name}</h4>
            <div style={{ display: "flex", flexWrap: "wrap", gap: "6px" }}>
              {ex.sets.map((s, j) => (
                <span key={j} style={{
                  fontSize: "12px",
                  fontFamily: theme.fontMono,
                  padding: "4px 8px",
                  borderRadius: "6px",
                  background: theme.bg,
                  color: theme.textSecondary,
                }}>
                  {s.weight}{unit}×{s.reps}
                </span>
              ))}
            </div>
          </div>
        ))}
      </div>

      <button onClick={onDone} style={{
        width: "100%",
        padding: "16px",
        marginTop: "16px",
        background: theme.accent,
        color: theme.accentText,
        border: "none",
        borderRadius: theme.radiusSm,
        fontSize: "16px",
        fontWeight: 700,
        cursor: "pointer",
      }}>
        返回首页
      </button>
    </div>
  );
}

// ═══════════════════════════════════════════════
// SCREEN: History (Calendar + List)
// ═══════════════════════════════════════════════
function HistoryScreen({ history, unit, onSelect }) {
  const today = new Date();
  const [calYear, setCalYear] = useState(today.getFullYear());
  const [calMonth, setCalMonth] = useState(today.getMonth());
  const [selectedDate, setSelectedDate] = useState(null);
  const [viewMode, setViewMode] = useState("calendar");

  const daysInMonth = getDaysInMonth(calYear, calMonth);
  const firstDay = getFirstDayOfMonth(calYear, calMonth);
  const monthNames = ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"];
  const dayNames = ["日", "一", "二", "三", "四", "五", "六"];

  const workoutDates = new Set(history.map(h => h.date));
  const filteredHistory = selectedDate
    ? history.filter(h => h.date === selectedDate)
    : history;

  const prevMonth = () => {
    if (calMonth === 0) { setCalMonth(11); setCalYear(calYear - 1); }
    else setCalMonth(calMonth - 1);
  };
  const nextMonth = () => {
    if (calMonth === 11) { setCalMonth(0); setCalYear(calYear + 1); }
    else setCalMonth(calMonth + 1);
  };

  return (
    <div style={{ padding: "16px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "20px", paddingTop: "8px" }}>
        <h1 style={{ fontSize: "28px", fontWeight: 700, margin: 0, letterSpacing: "-0.5px" }}>训练记录</h1>
        <div style={{
          display: "flex",
          background: theme.surface,
          borderRadius: "8px",
          border: `1px solid ${theme.border}`,
          overflow: "hidden",
        }}>
          {["calendar", "list"].map(m => (
            <button key={m} onClick={() => { setViewMode(m); setSelectedDate(null); }} style={{
              padding: "6px 14px",
              background: viewMode === m ? theme.accentDim : "transparent",
              color: viewMode === m ? theme.accent : theme.textSecondary,
              border: "none",
              fontSize: "12px",
              fontWeight: 600,
              cursor: "pointer",
            }}>
              {m === "calendar" ? "日历" : "列表"}
            </button>
          ))}
        </div>
      </div>

      {viewMode === "calendar" && (
        <>
          {/* Calendar Nav */}
          <div style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            marginBottom: "16px",
          }}>
            <button onClick={prevMonth} style={{ background: "none", border: "none", color: theme.textSecondary, cursor: "pointer", padding: "8px" }}><Icons.ChevronLeft /></button>
            <span style={{ fontSize: "16px", fontWeight: 600 }}>{calYear}年 {monthNames[calMonth]}</span>
            <button onClick={nextMonth} style={{ background: "none", border: "none", color: theme.textSecondary, cursor: "pointer", padding: "8px" }}><Icons.ChevronRight /></button>
          </div>

          {/* Calendar Grid */}
          <div style={{
            display: "grid",
            gridTemplateColumns: "repeat(7, 1fr)",
            gap: "2px",
            marginBottom: "20px",
          }}>
            {dayNames.map(d => (
              <div key={d} style={{
                textAlign: "center",
                fontSize: "11px",
                color: theme.textTertiary,
                padding: "8px 0",
                fontWeight: 600,
              }}>{d}</div>
            ))}
            {Array.from({ length: firstDay }, (_, i) => (
              <div key={`empty-${i}`} />
            ))}
            {Array.from({ length: daysInMonth }, (_, i) => {
              const day = i + 1;
              const dateStr = `${calYear}-${String(calMonth + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
              const hasWorkout = workoutDates.has(dateStr);
              const isSelected = selectedDate === dateStr;
              const isToday = day === today.getDate() && calMonth === today.getMonth() && calYear === today.getFullYear();

              return (
                <button
                  key={day}
                  onClick={() => setSelectedDate(isSelected ? null : dateStr)}
                  style={{
                    width: "100%",
                    aspectRatio: "1",
                    borderRadius: "10px",
                    border: isToday ? `1px solid ${theme.accent}` : "1px solid transparent",
                    background: isSelected ? theme.accent : hasWorkout ? theme.accentDim : "transparent",
                    color: isSelected ? theme.accentText : hasWorkout ? theme.accent : theme.text,
                    fontSize: "14px",
                    fontWeight: hasWorkout ? 700 : 400,
                    cursor: "pointer",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    position: "relative",
                  }}
                >
                  {day}
                  {hasWorkout && !isSelected && (
                    <div style={{
                      position: "absolute",
                      bottom: "4px",
                      width: "4px",
                      height: "4px",
                      borderRadius: "50%",
                      background: theme.accent,
                    }} />
                  )}
                </button>
              );
            })}
          </div>
        </>
      )}

      {/* Workout List */}
      <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
        {filteredHistory.length === 0 && (
          <div style={{ textAlign: "center", padding: "40px 0", color: theme.textTertiary, fontSize: "14px" }}>
            {selectedDate ? "当天无训练记录" : "暂无训练记录"}
          </div>
        )}
        {filteredHistory.map(w => (
          <button key={w.id} onClick={() => onSelect(w)} style={{
            background: theme.surface,
            border: `1px solid ${theme.border}`,
            borderRadius: theme.radiusSm,
            padding: "14px 16px",
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            cursor: "pointer",
            width: "100%",
            textAlign: "left",
          }}>
            <div>
              <div style={{ fontSize: "15px", fontWeight: 600, color: theme.text, marginBottom: "4px" }}>{w.templateName}</div>
              <div style={{ fontSize: "12px", color: theme.textSecondary }}>{w.date} · {w.duration}分钟 · {w.totalSets}组</div>
            </div>
            <div style={{ textAlign: "right" }}>
              <div style={{ fontSize: "16px", fontFamily: theme.fontMono, fontWeight: 700, color: theme.accent }}>{Math.round(w.totalVolume)}</div>
              <div style={{ fontSize: "11px", color: theme.textTertiary }}>{unit}</div>
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════
// SCREEN: Workout Detail
// ═══════════════════════════════════════════════
function WorkoutDetailScreen({ workout, unit, onBack }) {
  return (
    <div style={{ padding: "16px" }}>
      <div style={{ display: "flex", alignItems: "center", gap: "8px", marginBottom: "20px", paddingTop: "8px" }}>
        <button onClick={onBack} style={{ background: "none", border: "none", color: theme.textSecondary, cursor: "pointer", display: "flex", alignItems: "center" }}>
          <Icons.ChevronLeft />
        </button>
        <div>
          <h2 style={{ margin: 0, fontSize: "20px", fontWeight: 700 }}>{workout.templateName}</h2>
          <p style={{ margin: "2px 0 0", fontSize: "13px", color: theme.textSecondary }}>
            {workout.date} · {workout.duration}分钟
          </p>
        </div>
      </div>

      {/* Stats */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: "8px", marginBottom: "20px" }}>
        {[
          { label: "时长", val: `${workout.duration}分` },
          { label: "总组数", val: `${workout.totalSets}组` },
          { label: "总容量", val: `${Math.round(workout.totalVolume)}${unit}` },
        ].map(s => (
          <div key={s.label} style={{
            background: theme.surface,
            border: `1px solid ${theme.border}`,
            borderRadius: theme.radiusSm,
            padding: "12px",
            textAlign: "center",
          }}>
            <div style={{ fontSize: "16px", fontFamily: theme.fontMono, fontWeight: 700, color: theme.accent }}>{s.val}</div>
            <div style={{ fontSize: "11px", color: theme.textTertiary, marginTop: "2px" }}>{s.label}</div>
          </div>
        ))}
      </div>

      {/* Exercise detail */}
      {workout.exercises.map((ex, i) => (
        <div key={i} style={{
          background: theme.surface,
          borderRadius: theme.radiusSm,
          border: `1px solid ${theme.border}`,
          padding: "14px",
          marginBottom: "10px",
        }}>
          <h4 style={{ margin: "0 0 10px", fontSize: "15px", fontWeight: 600 }}>{ex.name}</h4>
          <div style={{
            display: "grid",
            gridTemplateColumns: "40px 1fr 1fr 1fr",
            gap: "4px",
            fontSize: "11px",
            color: theme.textTertiary,
            fontWeight: 600,
            marginBottom: "4px",
          }}>
            <div>组</div>
            <div style={{ textAlign: "center" }}>重量</div>
            <div style={{ textAlign: "center" }}>次数</div>
            <div style={{ textAlign: "center" }}>休息</div>
          </div>
          {ex.sets.map((s, j) => (
            <div key={j} style={{
              display: "grid",
              gridTemplateColumns: "40px 1fr 1fr 1fr",
              gap: "4px",
              padding: "6px 0",
              fontSize: "13px",
              fontFamily: theme.fontMono,
              color: theme.textSecondary,
              borderTop: j > 0 ? `1px solid ${theme.border}` : "none",
            }}>
              <div style={{ color: theme.textTertiary }}>{j + 1}</div>
              <div style={{ textAlign: "center", color: theme.text }}>{s.weight}{unit}</div>
              <div style={{ textAlign: "center", color: theme.text }}>{s.reps}</div>
              <div style={{ textAlign: "center" }}>{s.rest > 0 ? `${s.rest}s` : "-"}</div>
            </div>
          ))}
        </div>
      ))}
    </div>
  );
}

// ═══════════════════════════════════════════════
// SCREEN: Settings
// ═══════════════════════════════════════════════
function SettingsScreen({ settings, setSettings }) {
  const update = (key, val) => setSettings({ ...settings, [key]: val });

  const ToggleSwitch = ({ value, onChange }) => (
    <button onClick={() => onChange(!value)} style={{
      width: "48px",
      height: "28px",
      borderRadius: "14px",
      border: "none",
      background: value ? theme.accent : theme.border,
      position: "relative",
      cursor: "pointer",
      transition: "background 0.2s",
    }}>
      <div style={{
        width: "22px",
        height: "22px",
        borderRadius: "50%",
        background: value ? theme.accentText : theme.textSecondary,
        position: "absolute",
        top: "3px",
        left: value ? "23px" : "3px",
        transition: "left 0.2s",
      }} />
    </button>
  );

  return (
    <div style={{ padding: "16px" }}>
      <h1 style={{ fontSize: "28px", fontWeight: 700, margin: "8px 0 24px", letterSpacing: "-0.5px" }}>设置</h1>

      <div style={{ display: "flex", flexDirection: "column", gap: "2px" }}>
        {/* Unit */}
        <div style={{
          background: theme.surface,
          border: `1px solid ${theme.border}`,
          borderRadius: `${theme.radiusSm} ${theme.radiusSm} 0 0`,
          padding: "16px",
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
        }}>
          <div>
            <div style={{ fontSize: "15px", fontWeight: 500 }}>重量单位</div>
            <div style={{ fontSize: "12px", color: theme.textSecondary, marginTop: "2px" }}>切换公斤/磅</div>
          </div>
          <div style={{
            display: "flex",
            background: theme.bg,
            borderRadius: "8px",
            border: `1px solid ${theme.border}`,
            overflow: "hidden",
          }}>
            {["kg", "lb"].map(u => (
              <button key={u} onClick={() => update("unit", u)} style={{
                padding: "6px 16px",
                background: settings.unit === u ? theme.accentDim : "transparent",
                color: settings.unit === u ? theme.accent : theme.textSecondary,
                border: "none",
                fontSize: "13px",
                fontWeight: 600,
                cursor: "pointer",
              }}>{u}</button>
            ))}
          </div>
        </div>

        {/* Default Rest */}
        <div style={{
          background: theme.surface,
          border: `1px solid ${theme.border}`,
          borderTop: "none",
          padding: "16px",
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
        }}>
          <div>
            <div style={{ fontSize: "15px", fontWeight: 500 }}>默认休息时间</div>
            <div style={{ fontSize: "12px", color: theme.textSecondary, marginTop: "2px" }}>组间休息倒计时</div>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
            <button onClick={() => update("defaultRest", Math.max(15, settings.defaultRest - 15))} style={{
              width: "32px", height: "32px", borderRadius: "8px",
              background: theme.bg, border: `1px solid ${theme.border}`,
              color: theme.textSecondary, fontSize: "16px", cursor: "pointer",
              display: "flex", alignItems: "center", justifyContent: "center",
            }}>−</button>
            <span style={{ fontFamily: theme.fontMono, fontSize: "15px", fontWeight: 600, minWidth: "40px", textAlign: "center" }}>{settings.defaultRest}s</span>
            <button onClick={() => update("defaultRest", settings.defaultRest + 15)} style={{
              width: "32px", height: "32px", borderRadius: "8px",
              background: theme.bg, border: `1px solid ${theme.border}`,
              color: theme.textSecondary, fontSize: "16px", cursor: "pointer",
              display: "flex", alignItems: "center", justifyContent: "center",
            }}>+</button>
          </div>
        </div>

        {/* Timer Sound */}
        <div style={{
          background: theme.surface,
          border: `1px solid ${theme.border}`,
          borderTop: "none",
          padding: "16px",
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
        }}>
          <div>
            <div style={{ fontSize: "15px", fontWeight: 500 }}>计时器声音</div>
            <div style={{ fontSize: "12px", color: theme.textSecondary, marginTop: "2px" }}>休息结束时播放提示音</div>
          </div>
          <ToggleSwitch value={settings.timerSound} onChange={v => update("timerSound", v)} />
        </div>

        {/* Timer Vibrate */}
        <div style={{
          background: theme.surface,
          border: `1px solid ${theme.border}`,
          borderTop: "none",
          borderRadius: `0 0 ${theme.radiusSm} ${theme.radiusSm}`,
          padding: "16px",
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
        }}>
          <div>
            <div style={{ fontSize: "15px", fontWeight: 500 }}>计时器振动</div>
            <div style={{ fontSize: "12px", color: theme.textSecondary, marginTop: "2px" }}>休息结束时振动提醒</div>
          </div>
          <ToggleSwitch value={settings.timerVibrate} onChange={v => update("timerVibrate", v)} />
        </div>
      </div>

      <div style={{
        marginTop: "32px",
        textAlign: "center",
        color: theme.textTertiary,
        fontSize: "12px",
      }}>
        Workout Log v1.0 · Prototype
      </div>
    </div>
  );
}
