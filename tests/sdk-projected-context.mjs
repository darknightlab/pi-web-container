#!/usr/bin/env node
// Usage: node tests/sdk-projected-context.mjs /path/to/installed/pi-coding-agent
// Tests the actual module and CLI chunk, without rewriting or extracting code.
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';

const root = resolve(process.argv[2] ?? 'node_modules/@earendil-works/pi-coding-agent');
const chunks = join(root, 'dist/bundle/chunks');
const candidates = [];
for (const name of await readdir(chunks)) {
    if (name.endsWith('.js') && (await readFile(join(chunks, name), 'utf8')).includes('function buildSessionProjection(')) candidates.push(name);
}
assert.equal(candidates.length, 1, 'must identify exactly one CLI session projection chunk');
for (const [label, file] of [['module', join(root, 'dist/core/session-manager.js')], ['CLI bundle', join(chunks, candidates[0])]]) {
    const { buildSessionProjection: project } = await import(pathToFileURL(file));
    const entries = [];
    const add = (type, fields) => {
        const entry = { type, id: String(entries.length), parentId: entries.at(-1)?.id ?? null, timestamp: '2026-01-01T00:00:00Z', ...fields };
        entries.push(entry);
        return entry;
    };
    const stable = (list = entries, leaf) => {
        const a = project(list, leaf), b = project(list, leaf);
        assert.deepEqual(a, b);
        assert.notStrictEqual(a.messages, b.messages);
        a.messages.forEach((message, i) => assert.strictEqual(message, b.messages[i], `${label}: message ${i} identity`));
        a.entries.forEach((entry, i) => {
            assert.notStrictEqual(entry.messages, b.entries[i].messages);
            entry.messages.length = 0;
        });
        assert.deepEqual(project(list, leaf).messages, b.messages, 'caller array mutation must not corrupt cache');
        return b.messages;
    };
    const user = add('message', { message: { role: 'user', content: 'original' } });
    const assistant = add('message', { message: { role: 'assistant', content: null } });
    add('message', { message: { role: 'system', content: null } });
    const custom = add('custom_message', { customType: 'test', content: 'custom', display: true });
    add('branch_summary', { summary: 'branch', fromId: user.id });
    const before = stable();
    add('context_edit', { targetId: user.id, replacement: { content: 'edited' } });
    assert.equal(stable()[0].content, 'edited');
    assert.equal(stable(entries, custom.id)[0].content, 'original', 'edits are branch-local');
    add('context_edit', { targetId: assistant.id, replacement: { content: 'assistant edit' } });
    assert.deepEqual(stable()[1].content, [{ type: 'text', text: 'assistant edit' }]);
    add('context_edit', { targetId: user.id, replacement: { content: 'latest' } });
    assert.equal(stable()[0].content, 'latest', 'latest edit wins');
    add('context_edit', { targetId: custom.id, replacement: null });
    assert.ok(!stable().some(m => m.role === 'custom'), 'null replacement deletes');
    assert.equal(before[0].content, 'original', 'edits must not mutate original messages');
    add('compaction', { summary: 'compact', tokensBefore: 100, firstKeptEntryId: user.id, systemMessage: { role: 'system', content: 'checkpoint' } });
    const compacted = stable();
    assert.deepEqual(compacted.slice(0, 2).map(m => m.role), ['system', 'compactionSummary']);
    const summary = entries.at(-1);
    add('context_edit', { targetId: summary.id, replacement: { content: 'ignored' } });
    assert.equal(stable()[1].summary, 'compact', 'summary edits do not replace content');
    add('compaction', { summary: 'new compact', tokensBefore: 50, firstKeptEntryId: user.id });
    assert.equal(stable().filter(m => m.role === 'compactionSummary').length, 1, 'older retained compaction is suppressed');
    console.log(`PASS ${label}: stable identity, fresh arrays, context_edit and compaction semantics`);
}
