import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import test from 'node:test';
import vm from 'node:vm';

// Run against a patched upstream checkout; no React/browser rendering required.
const root = process.env.PI_WEB_TEST_ROOT ?? '/tmp/pwfix-next';
const source = await readFile(`${root}/components/AppShell.tsx`, 'utf8');
const { restoreTerminalTabs, TERMINAL_TABS_KEY } = await import(`${root}/components/terminal-tab-state.ts`);
const { newVncTab, restoreVncTabs } = await import(`${root}/components/vnc-tab-state.ts`);

test('AppShell persists and restores VNC identity, selection and panel state alongside terminals', () => {
  const start = source.indexOf('  useEffect(() => {\n    try {\n      const raw = window.sessionStorage.getItem(TERMINAL_TABS_KEY)');
  const end = source.indexOf('  const rememberSideTabs', start);
  assert.ok(start >= 0 && end > start);
  const tab = newVncTab();
  for (const open of [false, true]) {
    const store = new Map();
    let effects = [];
    const context = vm.createContext({
      terminalTabs: [], vncTabs: [tab], activeFileTabId: tab.id,
      rightPanelOpen: open, terminalsRestored: true,
      restoreTerminalTabs, restoreVncTabs, TERMINAL_TABS_KEY,
      window: { sessionStorage: { getItem: key => store.get(key) ?? null, setItem: (key, value) => store.set(key, value) } },
      useEffect: callback => effects.push(callback),
      setTerminalTabs: value => { context.terminalTabs = value; },
      setVncTabs: value => { context.vncTabs = value; },
      setActiveFileTabId: value => { context.activeFileTabId = value; },
      setRightPanelOpen: value => { context.rightPanelOpen = value; },
      setTerminalsRestored: value => { context.terminalsRestored = value; },
    });
    vm.runInContext(stripTypeScriptTypes(source.slice(start, end)), context);
    effects[1]();
    assert.deepEqual(JSON.parse(store.get(TERMINAL_TABS_KEY)).vncTabs, [tab]);
    context.vncTabs = []; context.activeFileTabId = null; context.rightPanelOpen = !open;
    effects[0]();
    assert.equal(context.vncTabs[0].id, tab.id);
    assert.equal(context.activeFileTabId, tab.id);
    assert.equal(context.rightPanelOpen, open);
  }
});

test('side-tab restore preserves an active VNC without replacing upstream session ownership logic', () => {
  const start = source.indexOf('  const sideTabOwner = activeSessionFamily?.root.id ?? null;');
  const end = source.indexOf('  // sessionStorage is empty during SSR.', start);
  assert.ok(start >= 0 && end > start);
  const context = vm.createContext({
    activeSessionFamily: null, catalogLoaded: true, initialSessionRestored: true,
    sideTabOwnerRef: { current: 'old' }, sideTabsReadyRef: { current: true },
    sideTabsSavedOnWorkspaceSwitchRef: { current: false },
    rememberSideTabs() {}, restoreSideTabs() {}, sideTabsKey() {},
    selectedSession: null, sessionCatalog: [], fileTabs: [], terminalTabs: [],
    vncTabs: [{ id: 'vnc:kept' }], activeFileTabId: 'vnc:kept', rightPanelOpen: true,
    setAgentTabs() {},
    setActiveFileTabId(value) { context.activeFileTabId = value; },
    setRightPanelOpen(value) { context.rightPanelOpen = value; },
    useEffect(callback) { callback(); },
  });
  vm.runInContext(stripTypeScriptTypes(source.slice(start, end)), context);
  assert.equal(context.activeFileTabId, 'vnc:kept');
  assert.equal(context.rightPanelOpen, true);
});
