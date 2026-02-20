
(function () {
    function q(sel, root) { return (root || document).querySelector(sel) }
    function qa(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)) }

    function setTheme(mode) {
        var html = document.documentElement;
        html.setAttribute('data-theme', mode);
        try { localStorage.setItem('wiki.theme', mode); } catch (e) { }
        var link = q('#hljs-theme');
        if (link) {
            if (mode === 'dark') { link.href = 'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css'; }
            else if (mode === 'light') { link.href = 'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css'; }
            else {
                var prefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
                link.href = prefersDark ? 'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css' : 'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css';
            }
        }
        qa('.theme-btn').forEach(function (b) { b.classList.remove('active') });
        var active = q('.theme-btn[data-mode="' + mode + '"]');
        if (active) active.classList.add('active');
    }

    (function () {
        var stored = null; try { stored = localStorage.getItem('wiki.theme'); } catch (e) { }
        var mode = stored || 'auto'; setTheme(mode);
        qa('.theme-btn').forEach(function (btn) {
            btn.addEventListener('click', function () {
                var m = btn.getAttribute('data-mode') || 'auto'; setTheme(m);
            });
        });
        if (window.matchMedia) {
            try {
                window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function () {
                    if ((localStorage.getItem('wiki.theme') || 'auto') === 'auto') setTheme('auto');
                });
            } catch (e) { }
        }
    })();

    qa('.acc-h').forEach(function (btn) {
        btn.addEventListener('click', function () {
            var id = btn.getAttribute('data-target'); var el = q('#' + id); if (!el) return;
            el.style.display = (el.style.display === 'none' || getComputedStyle(el).display === 'none') ? 'block' : 'none';
        });
    });
    qa('.acc-b').forEach(function (b) { if (b.id !== 'cats') b.style.display = 'none'; else b.style.display = 'block'; });

    window.__filter = function (input, id) {
        var ul = q('#' + id + ' ul'); if (!ul) return;
        var qv = (input.value || '').toLowerCase();
        qa('li', ul).forEach(function (li) {
            var a = q('a', li); var t = a ? (a.textContent || '').toLowerCase() : '';
            li.style.display = t.indexOf(qv) >= 0 ? '' : 'none';
        });
    };

    function initHL() { qa('pre code').forEach(function (block) { try { window.hljs.highlightElement(block); } catch (e) { } }); }
    if (window.hljs) { initHL(); } else { document.addEventListener('DOMContentLoaded', initHL); }

    function norm(t) {
        if (!t) return '';
        try { return t.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase(); } catch (e) { return (t + '').toLowerCase(); }
    }

    var fuse = null, data = null, loaded = false;
    function loadIndex() {
        if (loaded) return;
        loaded = true;
        fetch('/search-index.json').then(function (r) { return r.json() }).then(function (arr) {
            data = arr.map(function (d) {
                return {
                    Id: d.Id, Title: d.Title, Aliases: d.Aliases || [], Tags: d.Tags || [], Body: d.Body || '', Url: d.Url, Category: d.Category || '',
                    _t: norm(d.Title), _b: norm(d.Body), _a: (d.Aliases || []).map(norm), _g: (d.Tags || []).map(norm)
                };
            });
            fuse = new Fuse(data, {
                includeMatches: true,
                threshold: 0.33,
                minMatchCharLength: 2,
                keys: [
                    { name: '_t', weight: 0.6 },
                    { name: '_a', weight: 0.18 },
                    { name: '_g', weight: 0.14 },
                    { name: '_b', weight: 0.08 }
                ]
            });
        }).catch(function (e) { console.error('Search index load failed', e) });
    }

    var input = q('#search-input'); var box = q('#search-results');
    if (input) {
        input.addEventListener('focus', function () { loadIndex(); if (box) box.classList.add('open'); });
        input.addEventListener('blur', function () { setTimeout(function () { if (box) box.classList.remove('open'); }, 150); });
        var tId = 0;
        input.addEventListener('input', function () {
            if (!fuse) { loadIndex(); }
            var val = input.value.trim();
            if (!val) { if (box) { box.innerHTML = ''; } return; }
            clearTimeout(tId);
            tId = setTimeout(function () {
                if (!fuse) { return; }
                var qn = norm(val);
                var res = fuse.search(qn, { limit: 50 });
                box.innerHTML = res.map(renderHit).join('');
                box.classList.add('open');
            }, 120);
        });
    }

    function escapeHtml(s) {
        var map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
        return String(s || '').replace(/[&<>"']/g, function (c) { return map[c]; });
    }
    function escReg(s) { return (s + '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }
    function hlSnippet(text, term, radius) {
        if (!text) return '';
        var low = text.toLowerCase(); var lowTerm = term.toLowerCase();
        var i = low.indexOf(lowTerm);
        if (i < 0) { return escapeHtml(text.slice(0, 200)) + (text.length > 200 ? '…' : ''); }
        var start = Math.max(0, i - 120); var end = Math.min(text.length, i + term.length + 120);
        var pre = start > 0 ? '…' : ''; var post = end < text.length ? '…' : '';
        var raw = text.substring(start, end);
        var re = new RegExp(escReg(term), 'ig');
        return pre + escapeHtml(raw).replace(re, function (m) { return '<b>' + escapeHtml(m) + '</b>'; }) + post;
    }
    function renderHit(hit) {
        var d = hit.item;
        var sn = hlSnippet(d.Body, input.value, 140);
        return '<div class="hit"><a href="' + d.Url + '">' + escapeHtml(d.Title) + '</a><div class="snip">' + sn + '</div></div>';
    }

    document.addEventListener('DOMContentLoaded', function () {
        var burger = document.querySelector('.burger');
        var sidebar = document.querySelector('.sidebar');
        var overlay = document.querySelector('.drawer-overlay');
        if (!overlay) { overlay = document.createElement('div'); overlay.className = 'drawer-overlay'; document.body.appendChild(overlay); }
        function openDrawer() { if (sidebar) { sidebar.classList.add('open'); } if (overlay) { overlay.classList.add('visible'); } }
        function closeDrawer() { if (sidebar) { sidebar.classList.remove('open'); } if (overlay) { overlay.classList.remove('visible'); } }
        if (burger) { burger.addEventListener('click', function (e) { e.preventDefault(); openDrawer(); }); }
        if (overlay) { overlay.addEventListener('click', closeDrawer); }
        document.addEventListener('keydown', function (e) { if (e.key === 'Escape') closeDrawer(); });
    });

})();
