#!/usr/bin/env python3
"""Rocha+ LAB guard — hook do Claude Code (PreToolUse/PostToolUse/SubagentStop).

Uso: rocha_guard.py <modo>   (JSON do hook no stdin)
Modos: bash | write | read | mcp | agent-pre | agent-post | agent-stop

Saída: exit 0 = permitir; exit 2 = bloquear (mensagem em stderr volta ao Claude).
Nunca executa o comando analisado: só lê o texto.
Bypass total apenas pelo humano, iniciando o Claude Code com ROCHA_GUARD_ADMIN=1.
Falha FECHADA para bash/write/read/mcp; ABERTA para agent-* (só controle de consumo).
"""
import fnmatch
import hashlib
import json
import os
import re
import subprocess
import sys
import time

MAX_AGENTS_DEFAULT = 3
TTL_ACTIVE = 900        # s: entrada de agente "ativo" expira (evita travar)
TTL_CACHE = 86400       # s: resultado reutilizável

# ---------------------------------------------------------------- caminhos
PROTECTED = [re.compile(p, re.I) for p in (
    r'(^|/)lib/src/live/(channel_repository|open_tv_channels|channel_blocks)\.dart$',
    r'(^|/)\.github/workflows(/|$)',
    r'(^|/)tools/prepare_signed_build\.py$',
    r'candidate-?6|candidata-?6',
    r'(catalogo|catalog)[^/]*(oficial|official|congelad|frozen|aprovad)|sha256sums',
    r'payment|pagamento|receipt|mercadopago|asaas|owner-exemption|spark-|'
    r'single-account|resolve-test-account|firestore\.rules|firebase\.json|\.firebaserc',
)]
CREDS = re.compile(
    r'(^|/)(\.env[^/]*|[^/]*\.(jks|keystore|pem|p12|pfx)|key\.properties|google-services\.json|'
    r'[^/]*service-?account[^/]*\.json|id_(rsa|ed25519|ecdsa)[^/]*|\.netrc|\.git-credentials|'
    r'\.npmrc|\.pypirc)$|(^|/)\.(ssh|aws|gnupg|docker)(/|$)|(^|/)\.config/(gh|gcloud)(/|$)', re.I)
SELFPROT = re.compile(
    r'(^|/)\.claude/(settings[^/]*\.json|hooks(/|$))|(^|/)\.git/(config|hooks|HEAD|refs|packed-refs)', re.I)
PROTECTED_BRANCH = re.compile(r'candidate-?6|candidata-?6|frozen|freeze|checkpoint|backup', re.I)
SAFE_WRITE_ROOTS = ('/tmp/', '/var/tmp/')

# ---------------------------------------------------------------- bash
READERS = {'cat', 'head', 'tail', 'grep', 'egrep', 'fgrep', 'rg', 'less', 'more', 'wc', 'ls',
           'stat', 'file', 'diff', 'cmp', 'sha256sum', 'sha1sum', 'md5sum', 'nl', 'od', 'strings',
           'tree', 'du', 'sort', 'uniq', 'cut', 'echo', 'printf', 'pwd', 'which', 'type', 'true',
           'test', '[', 'basename', 'dirname', 'realpath', 'find', 'sed', 'date', 'cd'}
GIT_VAL_OPTS = {'-C', '-c', '--git-dir', '--work-tree', '--namespace', '--exec-path',
                '--super-prefix', '--config-env'}
GIT_BLOCK = {'push', 'send-pack', 'http-push', 'merge', 'pull', 'rebase', 'cherry-pick', 'filter-branch',
             'filter-repo', 'update-ref', 'replace', 'prune', 'credential', 'lfs', 'subtree', 'annex',
             'svn', 'daemon', 'fast-import', 'fast-export', 'gc', 'maintenance'}
GIT_WRITE = {'commit', 'add', 'rm', 'mv', 'revert', 'am', 'stash', 'tag', 'restore', 'notes',
             'apply', 'checkout', 'switch', 'branch', 'commit-tree', 'write-tree', 'read-tree'}
GIT_PATH_SUBS = {'add', 'rm', 'mv', 'restore', 'checkout', 'apply', 'am'}
BAD_GIT_C = re.compile(r'alias|url\.|credential|sshcommand|hookspath|fsmonitor|protocol|pager|editor|'
                       r'diff\.external|gpg\.program|askpass|include|insteadof', re.I)
GH_ALLOW = {('pr', 'view'), ('pr', 'list'), ('pr', 'diff'), ('pr', 'checks'), ('pr', 'status'),
            ('run', 'list'), ('run', 'view'), ('issue', 'view'), ('issue', 'list'),
            ('repo', 'view'), ('workflow', 'list'), ('workflow', 'view'), ('release', 'list'),
            ('release', 'view'), ('auth', 'status')}
NET_BLOCK = {'ssh', 'scp', 'sftp', 'rsync', 'nc', 'ncat', 'netcat', 'socat', 'telnet', 'ftp', 'tftp',
             'aria2c', 'mosh'}
HTTP_CLIENTS = {'curl', 'wget', 'http', 'https', 'xh', 'httpie'}
DEPLOY_ANY = {'firebase', 'firebase-tools', 'vercel', 'netlify', 'fastlane', 'fly', 'flyctl', 'heroku',
              'wrangler', 'supabase', 'eas', 'appcenter', 'serverless', 'sls', 'sentry-cli', 'terraform',
              'tofu', 'pulumi', 'helm', 'kubectl', 'gcloud', 'gsutil', 'bq', 'aws', 'az', 'stripe',
              'mercadopago', 'ngrok', 'cloudflared', 'gh-pages', 'surge', 'rclone'}
PKG_MANAGERS = {'npm', 'pnpm', 'yarn', 'bun', 'cargo', 'gem', 'pip', 'pip3', 'twine', 'dart', 'flutter',
                'gradle', 'gradlew', 'mvn', 'docker', 'podman', 'bundle', 'poetry', 'uv', 'npx'}
PKG_BAD_WORDS = {'publish', 'upload', 'deploy', 'login', 'logout', 'adduser', 'token', 'push', 'release'}
SENSITIVE_HOST = re.compile(
    r'mercadopago|mercadolibre|asaas|stripe\.com|pagseguro|paypal|pagar\.me|androidpublisher|'
    r'firebase|firestore|cloudfunctions|\.run\.app|identitytoolkit|securetoken|gerencianet|efi\.com', re.I)
INTERP = {'python', 'python3', 'python2', 'node', 'nodejs', 'perl', 'ruby', 'php', 'deno', 'bun', 'lua', 'sh',
          'bash', 'zsh', 'dash', 'ksh', 'pwsh', 'powershell'}
NET_LIBS = re.compile(r'requests\.(post|put|patch|delete)|urllib|http\.client|httpx|aiohttp|socket|smtplib|'
                      r'ftplib|paramiko|axios|fetch\(|XMLHttpRequest|child_process|net\.connect|Net::HTTP|LWP', re.I)
LOOSE_FORBIDDEN = re.compile(
    r'git\W{1,6}(push|merge|pull|rebase|cherry-pick|send-pack)\b|gh\W{1,6}(pr\W{1,6}merge|workflow\W{1,6}run|'
    r'api|release|secret)\b|firebase\W{1,6}deploy|gcloud|gsutil|twine\W{1,6}upload|npm\W{1,6}publish|'
    r'pub\W{1,6}publish|docker\W{1,6}push|rm\W{1,6}-\w*[rR]', re.I)
SEP = re.compile(r'\|\||&&|\$\(|<\(|[;|&\n(){}`]')


class Block(Exception):
    pass


def normalize(cmd):
    s = cmd.replace('\\\n', ' ')
    s = re.sub(r"[\\'\"]", '', s)
    s = re.sub(r'\$\{?IFS\}?', ' ', s)
    return s.replace('\t', ' ')


def base(tok):
    return os.path.basename(tok.rstrip('/')).lower()


def is_prot(p):
    p = p.lower()
    if not p.startswith('/'):
        p = p[2:] if p.startswith('./') else p
    return any(r.search(p) for r in PROTECTED)


def branch_of(directory):
    if os.environ.get('ROCHA_GUARD_TEST') == '1' and os.environ.get('ROCHA_GUARD_BRANCH'):
        return os.environ['ROCHA_GUARD_BRANCH']
    try:
        r = subprocess.run(['git', '-C', directory or '.', 'rev-parse', '--abbrev-ref', 'HEAD'],
                           capture_output=True, text=True, timeout=5)
        return r.stdout.strip() if r.returncode == 0 else ''
    except Exception:
        return ''


def require_lab_branch(directory, what):
    b = branch_of(directory)
    if not b.startswith('lab/') or PROTECTED_BRANCH.search(b):
        raise Block('%s só é permitido em branch lab/* não protegida (atual: %r). '
                    'Candidata 6, main e branches freeze/frozen/checkpoint/backup são somente leitura.' % (what, b))


def check_git(args, cwd):
    sub, rest, pre = None, [], []
    i = 0
    while i < len(args):
        a = args[i]
        if a in GIT_VAL_OPTS:
            pre.append((a, args[i + 1] if i + 1 < len(args) else ''))
            i += 2
            continue
        if a.startswith('--') and '=' in a:
            k, v = a.split('=', 1)
            pre.append((k, v))
            i += 1
            continue
        if a.startswith('-'):
            i += 1
            continue
        sub, rest = a.lower(), args[i + 1:]
        break
    directory = cwd
    for k, v in pre:
        if k in ('-c', '--config-env') and BAD_GIT_C.search(v):
            raise Block('git -c %s: alias/url/credencial/hook via -c é contorno bloqueado.' % v)
        if k in ('-C', '--work-tree') and v:
            directory = v if os.path.isabs(v) else os.path.join(cwd or '.', v)
        if k == '--git-dir':
            raise Block('git --git-dir não é permitido (pode apontar para outro repositório).')
    if sub is None:
        return
    if sub in GIT_BLOCK:
        raise Block('git %s bloqueado (push/merge/pull/rebase/cherry-pick e afins exigem autorização do Japa).' % sub)
    if sub == 'remote' and rest and rest[0].lower() not in ('-v', 'show', 'get-url'):
        raise Block('git remote só leitura (-v/show/get-url).')
    if sub == 'config':
        ok = ('--get', '--get-all', '--get-regexp', '--list', '-l', '--show-origin')
        if not rest or rest[0] not in ok:
            raise Block('git config só leitura (--get/--list).')
    if sub == 'reset' and any(x in ('--hard', '--merge', '--keep') for x in rest):
        raise Block('git reset --hard/--merge/--keep é destrutivo.')
    if sub == 'clean':
        raise Block('git clean é destrutivo.')
    if sub == 'checkout' and any(x in ('-f', '--force', '-B') for x in rest):
        raise Block('git checkout --force é destrutivo.')
    if sub == 'branch' and any(re.match(r'^-(d|D|m|M|-delete|-move|-force|f)$', x) for x in rest):
        raise Block('git branch -d/-D/-m/-f bloqueado (exclusão/renomeação de branch).')
    if sub == 'tag' and any(x in ('-d', '--delete', '-f', '--force') for x in rest):
        raise Block('git tag -d/-f bloqueado.')
    if sub == 'stash' and rest and rest[0].lower() in ('drop', 'clear'):
        raise Block('git stash drop/clear bloqueado.')
    if sub == 'reflog' and rest and rest[0].lower() in ('expire', 'delete'):
        raise Block('git reflog expire/delete bloqueado.')
    if sub in GIT_WRITE:
        require_lab_branch(directory, 'git %s' % sub)
    if sub in GIT_PATH_SUBS:
        for a in rest:
            if not a.startswith('-') and (is_prot(a) or CREDS.search(a) or SELFPROT.search(a)):
                raise Block('git %s em caminho protegido: %s' % (sub, a))


def check_gh(args):
    pos = []
    i = 0
    while i < len(args) and len(pos) < 2:
        a = args[i]
        if a in ('-R', '--repo', '--hostname'):
            i += 2
            continue
        if a.startswith('-'):
            if a in ('--version', '-h', '--help'):
                return
            i += 1
            continue
        pos.append(a.lower())
        i += 1
    if len(pos) < 2 or tuple(pos) not in GH_ALLOW:
        raise Block('gh %s bloqueado: só leitura (pr/run/issue/repo/workflow/release list|view, auth status). '
                    'gh api, pr merge, workflow run, release, secret etc. exigem autorização.' % ' '.join(pos))


def check_http(args):
    low = [a.lower() for a in args]
    for i, a in enumerate(low):
        if a in ('-d', '-f', '-t', '--upload-file', '--json', '--body-data', '--body-file') or \
                a.startswith(('--data', '--form', '--post')):
            raise Block('cliente HTTP com corpo/POST bloqueado.')
        if a in ('-x', '--request', '--method'):
            m = low[i + 1] if i + 1 < len(low) else ''
            if m not in ('get', 'head', 'options'):
                raise Block('cliente HTTP com método %r bloqueado.' % m)
        if a.startswith(('--request=', '--method=')) and a.split('=', 1)[1] not in ('get', 'head', 'options'):
            raise Block('cliente HTTP com método não-GET bloqueado.')
        if i == 0 and a in ('put', 'post', 'patch', 'delete'):
            raise Block('httpie com método de escrita bloqueado.')
    for a in low:
        if SENSITIVE_HOST.search(a):
            raise Block('host de pagamento/Firebase/produção bloqueado: %s' % a[:60])


def check_rm(args):
    for t in [a for a in args if not a.startswith('-')]:
        p = os.path.normpath(t)
        if not (p + '/').startswith(SAFE_WRITE_ROOTS) or '..' in t.split('/'):
            raise Block('exclusão fora de /tmp bloqueada (%s). Exclusão destrutiva exige autorização.' % t[:60])


def script_text_scan(tokens, cwd):
    """Para `python3 x.py`, `bash x.sh`, `node x.js`: lê o arquivo (não executa) e procura proibidos."""
    for t in tokens:
        if t.startswith('-') or not re.search(r'\.(py|sh|js|mjs|rb|pl|ps1)$', t):
            continue
        path = t if os.path.isabs(t) else os.path.join(cwd or '.', t)
        try:
            if os.path.getsize(path) > 200000:
                continue
            txt = open(path, encoding='utf-8', errors='ignore').read()
        except OSError:
            continue
        if LOOSE_FORBIDDEN.search(txt) or re.search(r'requests\.(post|put|patch|delete)|smtplib|paramiko', txt):
            raise Block('script %s contém comando/cliente proibido (inspeção estática; não executado).' % t)


def analyze_segment(seg, cwd):
    toks = [t for t in re.split(r'[\s,]+', seg) if t]
    while toks and re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', toks[0]):
        toks.pop(0)
    if not toks:
        return
    first = base(toks[0])
    if toks[0][0] in '$`':
        raise Block('comando indireto (variável/substituição como nome de comando) bloqueado.')
    names = [base(t) for t in toks]
    for t, n in zip(toks, names):
        if any(c in n for c in '*?[') and re.search(r'[a-z]', n):
            for s in ('git', 'gh', 'curl', 'wget', 'ssh', 'rm', 'firebase', 'gcloud', 'bash', 'sh'):
                if fnmatch.fnmatch(s, n):
                    raise Block('glob no nome de comando (%s) bloqueado.' % t)
    reader = first in READERS
    if first == 'find' and any(x in toks for x in ('-delete', '-exec', '-execdir', '-ok', '-okdir')):
        reader = False
    if first == 'sed' and any(re.match(r'^-[a-z]*i|^--in-place', x) for x in toks[1:]):
        reader = False
    if '>' in seg and reader:
        for t in toks:
            if is_prot(t) or CREDS.search(t) or SELFPROT.search(t):
                raise Block('redirecionamento para caminho protegido: %s' % t[:70])
    for t in toks:
        tl = t.lstrip('>').lower()
        if CREDS.search(tl):
            raise Block('caminho de credencial bloqueado (leitura/escrita): %s' % t[:70])
        if SELFPROT.search(tl) and not (reader and '>' not in seg):
            raise Block('arquivo de configuração/guard protegido: %s' % t[:70])
    if reader:
        return
    for i, n in enumerate(names):
        args = toks[i + 1:]
        if n == 'git':
            check_git(args, cwd)
        elif n == 'gh':
            check_gh(args)
        elif n in HTTP_CLIENTS:
            check_http(args)
        elif n in NET_BLOCK:
            raise Block('%s bloqueado (canal de rede arbitrário).' % n)
        elif n in DEPLOY_ANY:
            raise Block('%s bloqueado (deploy/nuvem/pagamento exigem autorização).' % n)
        elif n in PKG_MANAGERS:
            for a in args:
                al = a.lower()
                if al in PKG_BAD_WORDS or al.startswith('publish'):
                    raise Block('%s %s bloqueado (publicação/login).' % (n, a))
        elif n in ('rm', 'rmdir', 'unlink', 'shred', 'truncate'):
            check_rm(args)
        elif n == 'find' and '-delete' in args:
            raise Block('find -delete bloqueado.')
        elif n in ('dd', 'mkfs', 'mke2fs', 'fdisk', 'wipefs', 'mount', 'crontab', 'at', 'ln', 'chown'):
            raise Block('%s bloqueado (alteração de sistema/vínculo).' % n)
        elif n == 'chmod' and any(is_prot(a) or CREDS.search(a) for a in args):
            raise Block('chmod em caminho protegido bloqueado.')
        elif n in INTERP:
            script_text_scan(args, cwd)
            if n in ('python', 'python3', 'node', 'nodejs', 'perl', 'ruby', 'php') and \
                    any(a in ('-c', '-e', '-r', '-E') for a in args):
                joined = ' '.join(args)
                if LOOSE_FORBIDDEN.search(joined) or NET_LIBS.search(joined):
                    raise Block('código inline com comando/rede proibido bloqueado.')
    if first != 'git':
        for t in toks:
            if not t.startswith('-') and is_prot(t):
                raise Block('comando de escrita/execução toca área protegida: %s' % t[:70])


def check_bash(cmd, cwd):
    norm = normalize(cmd)
    if re.search(r'(^|[;&|(\n]\s*)(\$\(|`|\$\{?[A-Za-z_])', norm):
        raise Block('nome de comando vindo de variável/substituição bloqueado.')
    if re.search(r'\|\s*(sudo\s+)?(ba|z|da|k|c|fi)?sh\b|\|\s*(python\d?|node|perl|ruby)\b|\beval\b|'
                 r'base64\s+(-d|--decode)|xxd\s+-r|\bsource\s+<|\.\s+<\(|\bexec\s+\d?[<>]', norm):
        raise Block('execução indireta (pipe para shell/eval/base64 -d) bloqueada.')
    if re.search(r'(\$\(|`)[^)`]*\b(echo|printf|base64|rev|xxd|tr)\b', norm):
        raise Block('construção dinâmica de comando bloqueada.')
    if re.search(r'\b(python\d?|node|perl|ruby|php)\b.*\b(subprocess|os\.system|popen|child_process|exec)\b', norm) \
            and LOOSE_FORBIDDEN.search(norm):
        raise Block('interpretador chamando comando proibido bloqueado.')
    for seg in SEP.split(norm):
        analyze_segment(seg.strip(), cwd)


# ---------------------------------------------------------------- write/read
def project_root(cwd):
    return os.environ.get('CLAUDE_PROJECT_DIR') or cwd or os.getcwd()


def check_path(path, cwd, writing):
    full = os.path.realpath(path if os.path.isabs(path) else os.path.join(cwd or '.', path))
    root = os.path.realpath(project_root(cwd))
    rel = os.path.relpath(full, root) if (full + os.sep).startswith(root + os.sep) else None
    home = os.path.realpath(os.path.expanduser('~'))
    probe = (rel or full).replace(os.sep, '/')
    if CREDS.search(full.replace(os.sep, '/')):
        raise Block('caminho de credencial bloqueado: %s' % path)
    if not writing:
        return
    if SELFPROT.search(probe) or full.startswith(os.path.join(home, '.claude')):
        raise Block('configuração do guard/ECC protegida (alterar só pelo Japa): %s' % path)
    if rel is None:
        if full.startswith(SAFE_WRITE_ROOTS):
            return
        raise Block('escrita fora do projeto bloqueada: %s' % path)
    if is_prot(probe):
        raise Block('área protegida (Candidata 6 / catálogo / pagamentos / workflows / produção): %s' % rel)
    require_lab_branch(root, 'edição de arquivos')


def check_mcp(name):
    m = re.match(r'^mcp__(.+?)__(.+)$', name)
    if not m:
        return
    server, tool = m.group(1).lower(), m.group(2).lower()
    if server in ('memory', 'visualize', 'widgets', 'remote-browser', 'claude_ai'):
        return
    write = re.search(r'(send|forward|reply|create|update|delete|trash|share|publish|schedule|execute|fire|upload|'
                      r'write|apply|label|spam|status|budget|add_repo|copy|move|resolve|upsert|insert|post|run|'
                      r'cancel|remember|declare|pin|watch|contact|use_|generate|set_|add_)', tool)
    read = re.search(r'(^|_)(get|list|search|read|download|describe|whoami|info|stats|query|fetch|recall|find|'
                     r'graph|check|metadata|screenshot|help|overview|callers|impact|imports|neighbors|rank|trace|'
                     r'tests_for|node|options|fields|connectors|display)(_|$)', tool)
    if write or not read:
        raise Block('ferramenta MCP bloqueada (%s/%s): só leituras (get/list/search/read/query) são permitidas; '
                    'escrita/publicação exige autorização do Japa.' % (server, tool))


# ---------------------------------------------------------------- agentes
def state_dir():
    d = os.environ.get('ROCHA_GUARD_STATE_DIR') or os.path.join(project_root(None), '.claude', 'state')
    os.makedirs(d, exist_ok=True)
    return d


def load_state():
    try:
        with open(os.path.join(state_dir(), 'agents.json')) as f:
            return json.load(f)
    except Exception:
        return {'active': [], 'cache': {}}


def save_state(st):
    p = os.path.join(state_dir(), 'agents.json')
    tmp = p + '.tmp%d' % os.getpid()
    with open(tmp, 'w') as f:
        json.dump(st, f)
    os.replace(tmp, p)


def log(event, decision, reason, extra=''):
    try:
        with open(os.path.join(state_dir(), 'guard.log'), 'a') as f:
            f.write(json.dumps({'t': int(time.time()), 'event': event, 'decision': decision,
                                'reason': reason[:200], 'what': extra[:160]}, ensure_ascii=False) + '\n')
    except Exception:
        pass


def head_sha(cwd):
    if os.environ.get('ROCHA_GUARD_TEST') == '1' and 'ROCHA_GUARD_HEAD' in os.environ:
        return os.environ['ROCHA_GUARD_HEAD']
    try:
        r = subprocess.run(['git', '-C', project_root(cwd), 'rev-parse', 'HEAD'],
                           capture_output=True, text=True, timeout=5)
        d = subprocess.run(['git', '-C', project_root(cwd), 'status', '--porcelain'],
                           capture_output=True, text=True, timeout=5)
        return r.stdout.strip() + hashlib.sha1(d.stdout.encode()).hexdigest()[:8]
    except Exception:
        return ''


def agent_key(ti, cwd):
    atype = ti.get('subagent_type') or 'general-purpose'
    prompt = re.sub(r'\s+', ' ', (ti.get('prompt') or '').lower()).strip()
    return atype, hashlib.sha1((atype + '|' + prompt + '|' + head_sha(cwd)).encode()).hexdigest()


def agent_pre(p):
    ti = p.get('tool_input') or {}
    atype, key = agent_key(ti, p.get('cwd'))
    now = time.time()
    st = load_state()
    st['active'] = [a for a in st.get('active', []) if now - a['t'] < TTL_ACTIVE]
    st['cache'] = {k: v for k, v in st.get('cache', {}).items() if now - v['t'] < TTL_CACHE}
    hit = st['cache'].get(key)
    if hit and os.environ.get('ROCHA_FORCE_REANALYSE') != '1':
        save_state(st)
        raise Block('Análise idêntica já concluída neste commit/estado (%s). Reutilize o resultado:\n%s'
                    % (hit.get('agent'), hit.get('summary', '')[:1500]))
    limit = int(os.environ.get('ROCHA_MAX_AGENTS', MAX_AGENTS_DEFAULT))
    if len(st['active']) >= limit:
        save_state(st)
        raise Block('Limite de %d agentes simultâneos atingido. Aguarde um terminar ou consolide a tarefa em '
                    'um agente já ativo.' % limit)
    st['active'].append({'id': p.get('tool_use_id') or '%s-%s' % (key, now), 'key': key, 'agent': atype, 't': now})
    save_state(st)


def summarize(resp):
    try:
        txt = resp if isinstance(resp, str) else json.dumps(resp, ensure_ascii=False)
    except Exception:
        txt = str(resp)
    return txt[:2000]


def agent_post(p):
    ti = p.get('tool_input') or {}
    if ti.get('run_in_background'):
        return  # resultado final chega em SubagentStop
    atype, key = agent_key(ti, p.get('cwd'))
    st = load_state()
    st['active'] = [a for a in st.get('active', []) if a.get('id') != p.get('tool_use_id') and a.get('key') != key]
    st['cache'][key] = {'t': time.time(), 'agent': atype, 'summary': summarize(p.get('tool_response'))}
    save_state(st)


def agent_stop(p):
    st = load_state()
    at = p.get('agent_type')
    idx = next((i for i, a in enumerate(st.get('active', [])) if not at or a.get('agent') == at), None)
    if idx is None and st.get('active'):
        idx = 0
    if idx is not None:
        a = st['active'].pop(idx)
        msg = p.get('last_assistant_message')
        if msg:
            st['cache'][a['key']] = {'t': time.time(), 'agent': a.get('agent'), 'summary': summarize(msg)}
    save_state(st)


# ---------------------------------------------------------------- main
def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ''
    if os.environ.get('ROCHA_GUARD_ADMIN') == '1':
        return 0
    try:
        p = json.load(sys.stdin)
    except Exception:
        p = {}
    ti = p.get('tool_input') or {}
    cwd = p.get('cwd') or os.getcwd()
    what = ''
    try:
        if mode == 'bash':
            what = ti.get('command', '')
            check_bash(what, cwd)
        elif mode in ('write', 'read'):
            what = ti.get('file_path') or ti.get('notebook_path') or ti.get('path') or ''
            if what:
                check_path(what, cwd, mode == 'write')
        elif mode == 'mcp':
            what = p.get('tool_name', '')
            check_mcp(what)
        elif mode == 'agent-pre':
            what = ti.get('subagent_type', '')
            try:
                agent_pre(p)
            except Block:
                raise
            except Exception as e:  # consumo: falha aberta
                log(mode, 'error-open', repr(e))
                return 0
        elif mode == 'agent-post':
            agent_post(p)
        elif mode == 'agent-stop':
            agent_stop(p)
        else:
            raise Block('modo desconhecido: %r' % mode)
    except Block as b:
        log(mode, 'block', str(b), what)
        sys.stderr.write('[rocha-guard] BLOQUEADO: %s\n' % b)
        return 2
    except Exception as e:
        if mode in ('agent-post', 'agent-stop'):
            return 0
        log(mode, 'error-closed', repr(e), what)
        sys.stderr.write('[rocha-guard] erro interno (falha fechada): %r\n' % e)
        return 2
    log(mode, 'allow', '', what)
    return 0


if __name__ == '__main__':
    sys.exit(main())
