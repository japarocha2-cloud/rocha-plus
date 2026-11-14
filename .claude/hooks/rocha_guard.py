#!/usr/bin/env python3
"""Rocha+ LAB guard — hook do Claude Code (PreToolUse/PostToolUse/SubagentStop).

Uso: rocha_guard.py <modo>   (JSON do hook no stdin)
Modos: bash | write | read | mcp | agent-pre | agent-post | agent-stop

Saída: exit 0 = permitir; exit 2 = bloquear (mensagem em stderr volta ao Claude).
Só LÊ o texto do comando: nunca o executa.
Bypass total apenas pelo humano, iniciando o Claude Code com ROCHA_GUARD_ADMIN=1.
Falha FECHADA para bash/write/read/mcp; ABERTA só para agent-* (controle de consumo).

LIMITE CONHECIDO: análise de texto é heurística, não sandbox. Ela reduz o risco, não o elimina;
a barreira real continua sendo "sem credenciais de escrita no ambiente LAB".
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
TTL_ACTIVE = 1800       # s: entrada de agente "ativo" expira (evita travar o limite)
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
ANCHORS = ['lib/src/live/channel_repository.dart', 'lib/src/live/open_tv_channels.dart',
           'lib/src/live/channel_blocks.dart', '.github/workflows/x.yml', 'tools/prepare_signed_build.py',
           'firestore.rules', 'firebase.json', '.firebaserc']
PROT_DIRS = {'.github', '.github/workflows', 'lib/src/live'}
CREDS = re.compile(
    r'(^|/)(\.env[^/]*|[^/]*\.(jks|keystore|pem|p12|pfx)|key\.properties|google-services\.json|'
    r'[^/]*service-?account[^/]*\.json|id_(rsa|ed25519|ecdsa)[^/]*|\.netrc|\.git-credentials|'
    r'\.npmrc|\.pypirc)$|(^|/)\.(ssh|aws|gnupg|docker)(/|$)|(^|/)\.config/(gh|gcloud)(/|$)', re.I)
SELFPROT = re.compile(
    r'(^|/)\.claude/(settings[^/]*\.json|hooks(/|$))|(^|/)\.git/(config|hooks|HEAD|refs|packed-refs)', re.I)
PROTECTED_BRANCH = re.compile(r'candidate-?6|candidata-?6|frozen|freeze|checkpoint|backup', re.I)
SAFE_WRITE_ROOTS = ('/tmp/', '/var/tmp/')
REGENERABLE = {'build', '.dart_tool', '__pycache__', '.pytest_cache', 'coverage', 'node_modules'}
ALLOWED_VARS = {'HOME', 'PWD', 'OLDPWD', 'USER', 'TMPDIR', 'CLAUDE_PROJECT_DIR', '?', '$'}

# ---------------------------------------------------------------- bash
PURE_READERS = {'cat', 'head', 'tail', 'grep', 'egrep', 'fgrep', 'rg', 'less', 'more', 'wc', 'ls',
                'stat', 'file', 'diff', 'cmp', 'sha256sum', 'sha1sum', 'md5sum', 'nl', 'od', 'strings',
                'tree', 'du', 'cut', 'echo', 'printf', 'pwd', 'which', 'basename', 'dirname', 'realpath',
                'get-content', 'select-string', 'get-childitem', 'get-filehash', 'type', 'dir'}
READERS = PURE_READERS | {'sort', 'uniq', 'true', 'test', '[', 'find', 'sed', 'date', 'cd'}
GIT_VAL_OPTS = {'-C', '-c', '--git-dir', '--work-tree', '--namespace', '--exec-path',
                '--super-prefix', '--config-env'}
GIT_BLOCK = {'push', 'send-pack', 'http-push', 'merge', 'pull', 'rebase', 'cherry-pick', 'filter-branch',
             'filter-repo', 'update-ref', 'symbolic-ref', 'replace', 'prune', 'credential', 'lfs', 'subtree',
             'annex', 'svn', 'daemon', 'fast-import', 'fast-export', 'gc', 'maintenance', 'bisect',
             'difftool', 'mergetool', 'instaweb', 'web--browse'}
GIT_ALWAYS_LAB = {'commit', 'add', 'rm', 'mv', 'revert', 'reset', 'notes', 'commit-tree', 'write-tree',
                  'read-tree', 'restore', 'apply', 'am'}
BAD_GIT_C = re.compile(r'alias|url\.|credential|sshcommand|hookspath|fsmonitor|protocol|pager|editor|'
                       r'diff\.external|gpg\.program|askpass|include|insteadof|core\.worktree', re.I)
GH_ALLOW = {('pr', 'view'), ('pr', 'list'), ('pr', 'diff'), ('pr', 'checks'), ('pr', 'status'),
            ('run', 'list'), ('run', 'view'), ('issue', 'view'), ('issue', 'list'),
            ('repo', 'view'), ('workflow', 'list'), ('workflow', 'view'), ('release', 'list'),
            ('release', 'view'), ('auth', 'status')}
NET_BLOCK = {'ssh', 'scp', 'sftp', 'rsync', 'nc', 'ncat', 'netcat', 'socat', 'telnet', 'ftp', 'tftp',
             'aria2c', 'mosh', 'patch'}
HTTP_CLIENTS = {'curl', 'wget', 'http', 'https', 'xh', 'httpie', 'invoke-restmethod', 'irm',
                'invoke-webrequest', 'iwr', 'start-bitstransfer'}
DEPLOY_ANY = {'firebase', 'firebase-tools', 'vercel', 'netlify', 'fastlane', 'fly', 'flyctl', 'heroku',
              'wrangler', 'supabase', 'eas', 'appcenter', 'serverless', 'sls', 'sentry-cli', 'terraform',
              'tofu', 'pulumi', 'helm', 'kubectl', 'gcloud', 'gsutil', 'bq', 'aws', 'az', 'stripe',
              'mercadopago', 'ngrok', 'cloudflared', 'gh-pages', 'surge', 'rclone'}
PKG_MANAGERS = {'npm', 'pnpm', 'yarn', 'bun', 'cargo', 'gem', 'pip', 'pip3', 'twine', 'dart', 'flutter',
                'gradle', 'gradlew', 'mvn', 'docker', 'podman', 'bundle', 'poetry', 'uv', 'npx', 'make'}
PKG_BAD_WORDS = {'publish', 'upload', 'deploy', 'login', 'logout', 'adduser', 'token', 'push', 'release',
                 'ship', 'prod', 'production'}
RM_NAMES = {'rm', 'rmdir', 'unlink', 'shred', 'truncate', 'remove-item', 'ri', 'del', 'erase', 'rd'}
WRITE_VERBS = {'cp', 'mv', 'rm', 'ln', 'install', 'rsync', 'tar', 'unzip', 'rmdir', 'remove-item', 'copy-item',
               'move-item', 'cpi', 'mi', 'xcopy', 'robocopy', 'copy', 'move', 'ditto', 'tee', 'dd'}
SENSITIVE_HOST = re.compile(
    r'mercadopago|mercadolibre|asaas|stripe\.com|pagseguro|paypal|pagar\.me|androidpublisher|'
    r'firebase|firestore|cloudfunctions|\.run\.app|identitytoolkit|securetoken|gerencianet|efi\.com', re.I)
INTERP = {'python', 'python3', 'python2', 'node', 'nodejs', 'perl', 'ruby', 'php', 'deno', 'bun', 'lua', 'sh',
          'bash', 'zsh', 'dash', 'ksh', 'pwsh', 'powershell'}
NET_LIBS = re.compile(r'requests\.(post|put|patch|delete|request)|urllib|http\.client|httpx|aiohttp|socket|'
                      r'smtplib|ftplib|paramiko|axios|fetch\(|XMLHttpRequest|child_process|net\.connect|'
                      r'Net::HTTP|LWP|require\([\'"]https?[\'"]\)|\bhttps?\.request', re.I)
DESTRUCTIVE_CODE = re.compile(r'shutil\.rmtree|os\.(remove|unlink|rmdir|removedirs|system|popen)|rmSync|'
                              r'unlinkSync|rimraf|fs\.rm|Remove-Item|subprocess', re.I)
LOOSE_FORBIDDEN = re.compile(
    r'\bgit\W{1,6}(push|merge|pull|rebase|cherry-pick|send-pack)\b|\bgh\W{1,6}(pr\W{1,6}merge|workflow\W{1,6}run|'
    r'api|release|secret)\b|\bfirebase\W{1,6}deploy|\bgcloud\b|\bgsutil\b|\btwine\W{1,6}upload|\bnpm\W{1,6}publish|'
    r'\bpub\W{1,6}publish|\bdocker\W{1,6}push|\brm\W{1,6}-\w*[rR]', re.I)
SEP = re.compile(r'\|\||&&|\$\(|<\(|[;|&\n(){}`]')
HEREDOC = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_]\w*)\1[^\n]*\n(.*?)\n[ \t]*\2[ \t]*(?:\n|$)", re.S)


class Block(Exception):
    pass


# ---------------------------------------------------------------- utilidades
def project_root(cwd=None):
    return os.environ.get('CLAUDE_PROJECT_DIR') or cwd or os.getcwd()


def clean(p):
    p = p.replace('\\', '/').lower().lstrip('>')
    root = os.path.realpath(project_root()).replace('\\', '/').lower()
    if p.startswith(root + '/'):
        p = p[len(root) + 1:]
    if p and not p.startswith('/'):
        p = os.path.normpath(p)
    return p


def is_prot(p):
    c = clean(p)
    return any(r.search(c) for r in PROTECTED)


def touches_prot(p):
    c = clean(p)
    if any(r.search(c) for r in PROTECTED):
        return True
    c = c.rstrip('/')
    if c in ('.', '', '..', '/'):
        return False
    return any(a == c or a.startswith(c + '/') for a in ANCHORS)


def base(tok):
    return os.path.basename(tok.rstrip('/')).lower()


def normalize(cmd, mode):
    s = cmd.replace('\\\r\n', '').replace('\\\n', '')
    if mode == 'slash':
        s = s.replace('\\', '/')
        s = re.sub(r"['\"]", '', s)
    else:
        s = re.sub(r"[\\'\"]", '', s)
    return s.replace('\t', ' ')


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


def check_code(txt, label, paths):
    """Código que será executado por um interpretador (inline, heredoc ou arquivo)."""
    if LOOSE_FORBIDDEN.search(txt) or NET_LIBS.search(txt) or DESTRUCTIVE_CODE.search(txt):
        raise Block('%s contém comando/rede/exclusão proibidos (inspeção estática; não executado).' % label)
    if paths:
        for t in re.findall(r'[\w./\\-]{4,}', txt):
            if is_prot(t) or CREDS.search(clean(t)) or SELFPROT.search(clean(t)):
                raise Block('%s toca caminho protegido: %s' % (label, t[:60]))


def script_text_scan(tokens, cwd):
    for t in tokens:
        if t.startswith('-') or not re.search(r'\.(py|sh|js|mjs|rb|pl|ps1)$', t):
            continue
        path = t if os.path.isabs(t) else os.path.join(cwd or '.', t)
        try:
            if os.path.getsize(path) > 200000:
                continue
            with open(path, encoding='utf-8', errors='ignore') as f:
                txt = f.read()
        except OSError:
            continue
        check_code(txt, 'script %s' % t, False)


# ---------------------------------------------------------------- git / gh / http / rm
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
        if re.match(r'^-[cC].+', a):
            pre.append((a[:2], a[2:]))
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
    if any('::' in a for a in rest):
        raise Block('git com transporte ext::/remoto helper bloqueado.')
    if sub in GIT_BLOCK:
        raise Block('git %s bloqueado (push/merge/pull/rebase/cherry-pick e afins exigem autorização do Japa).' % sub)
    if sub == 'remote' and rest and rest[0].lower() not in ('-v', 'show', 'get-url'):
        raise Block('git remote só leitura (-v/show/get-url).')
    if sub == 'config':
        ok = ('--get', '--get-all', '--get-regexp', '--list', '-l', '--show-origin')
        if not rest or rest[0] not in ok:
            raise Block('git config só leitura (--get/--list).')
    if sub == 'fetch':
        for a in rest:
            if ':' in a and not a.startswith(('http', 'git@', 'ssh:', '-')):
                dst = a.split(':', 1)[1].lstrip('+')
                if not dst.startswith('refs/remotes/'):
                    raise Block('git fetch com refspec cujo destino não é refs/remotes/ bloqueado '
                                '(moveria branches locais, inclusive main).')
    if sub == 'reset' and any(x in ('--hard', '--merge', '--keep', '--soft') or
                              re.match(r'^(HEAD[~^{@]|@|origin/|[0-9a-f]{7,40}$)', x) for x in rest):
        raise Block('git reset que move/descarta commits (--hard/--merge/--keep/--soft/commit-ish) é destrutivo.')
    if sub == 'clean':
        raise Block('git clean é destrutivo.')
    if sub == 'checkout':
        if any(re.match(r'^-[a-zA-Z]*[fB]', x) or x == '--force' for x in rest):
            raise Block('git checkout -f/-B/--force é destrutivo.')
        if '--' in rest or '.' in rest:
            raise Block('git checkout -- / . descarta alterações (destrutivo).')
    if sub == 'restore' and not any(x in ('--staged', '-S') for x in rest):
        raise Block('git restore sem --staged descarta alterações (destrutivo).')
    if sub == 'apply' and not any(x in ('--check', '--stat', '--numstat', '--summary') for x in rest):
        raise Block('git apply só com --check/--stat/--numstat/--summary (patch pode tocar área protegida).')
    if sub == 'am':
        raise Block('git am bloqueado (aplica patches/commits).')
    if sub == 'branch' and any((x.startswith('-') and not x.startswith('--') and re.search(r'[dDmMfF]', x[1:]))
                               or x in ('--delete', '--move', '--force', '--copy') for x in rest):
        raise Block('git branch -d/-D/-m/-f bloqueado (exclusão/renomeação de branch).')
    if sub == 'tag' and any(x in ('-d', '--delete', '-f', '--force') for x in rest):
        raise Block('git tag -d/-f bloqueado.')
    if sub == 'stash' and rest and rest[0].lower() in ('drop', 'clear'):
        raise Block('git stash drop/clear bloqueado.')
    if sub == 'reflog' and rest and rest[0].lower() in ('expire', 'delete'):
        raise Block('git reflog expire/delete bloqueado.')
    if sub == 'worktree' and rest and rest[0].lower() in ('remove', 'prune', 'move'):
        raise Block('git worktree remove/prune/move bloqueado.')
    if sub == 'submodule' and ('foreach' in rest or 'update' in rest):
        raise Block('git submodule foreach/update bloqueado (executa comandos/rede).')
    modifies = sub in GIT_ALWAYS_LAB or \
        (sub == 'stash' and not (rest and rest[0].lower() in ('list', 'show'))) or \
        (sub == 'tag' and rest and not any(x in ('-l', '--list', '-n') for x in rest))
    if modifies:
        require_lab_branch(directory, 'git %s' % sub)
    if sub in ('add', 'rm', 'mv', 'restore', 'checkout'):
        for a in rest:
            if a.startswith('-'):
                continue
            # `git add` só prepara o commit (humano revisa); restore/checkout/rm/mv sobre o guard são bloqueados
            if touches_prot(a) or CREDS.search(clean(a)) or (sub != 'add' and SELFPROT.search(clean(a))):
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


def check_http(name, args):
    safe = ('get', 'head', 'options')
    for i, a in enumerate(args):
        al = a.lower()
        nxt = (args[i + 1] if i + 1 < len(args) else '').lower()
        if al in ('-body', '-infile', '-form'):
            raise Block('cliente HTTP com corpo bloqueado.')
        if al == '-method' and nxt not in safe:
            raise Block('cliente HTTP com método %r bloqueado.' % nxt)
        if a.startswith('--'):
            k, _, v = al.partition('=')
            if k in ('--data', '--data-raw', '--data-binary', '--data-urlencode', '--data-ascii', '--form',
                     '--form-string', '--upload-file', '--json', '--post-data', '--post-file', '--body-data',
                     '--body-file', '--post301', '--post302', '--post303'):
                raise Block('cliente HTTP com corpo/POST bloqueado.')
            if k in ('--request', '--method') and (v or nxt) not in safe:
                raise Block('cliente HTTP com método não-GET bloqueado.')
        elif a.startswith('-') and len(a) > 1 and not a.startswith('-m'):
            letters = a[1:]
            if 'X' in letters:
                m = (letters.split('X', 1)[1] or args[i + 1] if i + 1 < len(args) or letters.split('X', 1)[1]
                     else '').lower()
                if m not in safe:
                    raise Block('cliente HTTP com método %r bloqueado.' % m)
                letters = letters.split('X', 1)[0]
            if name == 'curl' and re.search(r'[dFT]', letters):
                raise Block('curl com corpo/upload (-d/-F/-T) bloqueado.')
            if name in ('http', 'https', 'xh', 'httpie') and 'f' in letters:
                raise Block('httpie --form bloqueado.')
        if name in ('http', 'https', 'xh', 'httpie'):
            if al in ('put', 'post', 'patch', 'delete'):
                raise Block('httpie com método de escrita bloqueado.')
            if not al.startswith(('http', '-', '/')) and re.match(r'^[^/:\s]+(:=|=[^=]|@)', a):
                raise Block('httpie com item de dados (POST implícito) bloqueado.')
    for a in args:
        if SENSITIVE_HOST.search(a):
            raise Block('host de pagamento/Firebase/produção bloqueado: %s' % a[:60])


def check_rm(args):
    for t in [a for a in args if not a.startswith('-')]:
        c = clean(t)
        if c.startswith('/tmp/') or c.startswith('/var/tmp/'):
            if '..' not in c.split('/'):
                continue
        elif not c.startswith('/') and '..' not in c.split('/') and \
                os.path.basename(c.rstrip('/')) in REGENERABLE and not touches_prot(c):
            continue
        raise Block('exclusão bloqueada (%s): só /tmp e diretórios regeneráveis (%s).'
                    % (t[:60], ', '.join(sorted(REGENERABLE))))


# ---------------------------------------------------------------- segmento
def is_runner(toks):
    t = [x.lower() for x in toks]
    b = base(toks[0])
    if b in ('python', 'python3') and '-m' in t and ('unittest' in t or 'pytest' in t):
        return True
    if b in ('pytest', 'py.test'):
        return True
    if b in ('python', 'python3') and t[1:3] == ['-m', 'json.tool'] and \
            len([x for x in toks[3:] if not x.startswith('-')]) <= 1:
        return True
    if b in ('flutter', 'dart') and ('test' in t or 'analyze' in t):
        return True
    return b in ('npm', 'yarn', 'pnpm') and 'test' in t


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
    if 'xargs' in names or 'parallel' in names:
        if any(n in ('git', 'gh', 'curl', 'wget', 'rm', 'sh', 'bash', 'firebase', 'npm') for n in names):
            raise Block('xargs/parallel com comando sensível bloqueado (argumentos vêm do stdin).')
    runner = is_runner(toks)
    reader = first in READERS
    if first == 'find' and any(x in toks for x in ('-delete', '-exec', '-execdir', '-ok', '-okdir',
                                                   '-fprint', '-fprintf', '-fls')):
        reader = False
    if first == 'sed':
        if any(re.match(r'^-[a-z]*i|^--in-place', x) for x in toks[1:]):
            reader = False
        elif re.search(r'(^|[;{}\s])[\d$,]*[we]\s+\S|/[a-zA-Z]*[we][a-zA-Z]*(\s|;|$)', ' '.join(toks[1:])):
            raise Block('sed com comando/flag w ou e (escreve arquivo ou executa) bloqueado.')
    if first == 'cd' and any(clean(t).rstrip('/') in PROT_DIRS for t in toks[1:]):
        raise Block('cd para diretório protegido bloqueado (evita caminhos relativos para contornar).')
    if reader and first not in PURE_READERS:
        for t in toks[1:]:
            if is_prot(t) or CREDS.search(clean(t)) or SELFPROT.search(clean(t)):
                raise Block('%s com caminho protegido bloqueado (pode escrever): %s' % (first, t[:70]))
    if '>' in seg and reader:
        for t in toks:
            if is_prot(t) or CREDS.search(clean(t)) or SELFPROT.search(clean(t)):
                raise Block('redirecionamento para caminho protegido: %s' % t[:70])
    for t in toks:
        tl = clean(t)
        if CREDS.search(tl):
            raise Block('caminho de credencial bloqueado (leitura/escrita): %s' % t[:70])
        if SELFPROT.search(tl) and not runner and first != 'git' and not (reader and '>' not in seg):
            raise Block('arquivo de configuração/guard protegido: %s' % t[:70])
    if reader:
        return
    for i, n in enumerate(names):
        args = toks[i + 1:]
        if n == 'git' or (n.startswith('git-') and len(n) > 4):
            check_git(args if n == 'git' else [n[4:]] + args, cwd)
            break
        elif n == 'gh':
            check_gh(args)
            break
        elif n in HTTP_CLIENTS:
            check_http(n, args)
        elif n in NET_BLOCK:
            raise Block('%s bloqueado (canal de rede arbitrário / aplica patches).' % n)
        elif n in DEPLOY_ANY:
            raise Block('%s bloqueado (deploy/nuvem/pagamento exigem autorização).' % n)
        elif n in PKG_MANAGERS:
            for a in args:
                al = a.lower()
                if al in PKG_BAD_WORDS or al.startswith('publish'):
                    raise Block('%s %s bloqueado (publicação/deploy/login).' % (n, a))
        elif n in RM_NAMES:
            check_rm(args)
        elif n == 'find' and '-delete' in args:
            raise Block('find -delete bloqueado.')
        elif n in ('awk', 'gawk', 'mawk', 'nawk') and re.search(r'system|popen|getline|print[^;]*>', ' '.join(args)):
            raise Block('awk com system/getline/redirecionamento bloqueado.')
        elif n in ('dd', 'mkfs', 'mke2fs', 'fdisk', 'wipefs', 'mount', 'crontab', 'at', 'ln', 'chown'):
            raise Block('%s bloqueado (alteração de sistema/vínculo).' % n)
        elif n == 'chmod' and any(touches_prot(a) or CREDS.search(clean(a)) for a in args):
            raise Block('chmod em caminho protegido bloqueado.')
        elif n in INTERP:
            script_text_scan(args, cwd)
            if n in ('python', 'python3', 'node', 'nodejs', 'perl', 'ruby', 'php') and \
                    any(a in ('-c', '-e', '-r', '-E') for a in args):
                check_code(' '.join(args), 'código inline', True)
        if n in WRITE_VERBS:
            for a in args:
                if not a.startswith('-') and touches_prot(a):
                    raise Block('%s em caminho protegido (ou diretório que o contém): %s' % (n, a[:70]))
    if first != 'git' and not runner:
        for t in toks:
            if not t.startswith('-') and is_prot(t):
                raise Block('comando de escrita/execução toca área protegida: %s' % t[:70])


def split_heredocs(cmd):
    bodies = []

    def repl(m):
        line = cmd[cmd.rfind('\n', 0, m.start()) + 1:m.start()]
        if any(base(t) in INTERP for t in re.split(r'[\s;|&()]+', line) if t):
            bodies.append(m.group(3))
        return m.group(0).split('\n', 1)[0] + '\n'
    return HEREDOC.sub(repl, cmd), bodies


def check_bash(cmd, cwd):
    text, bodies = split_heredocs(cmd)
    for b in bodies:
        check_code(b, 'código via here-doc', True)
    for m in re.finditer(r"\b(?:python3?|node|nodejs|perl|ruby|php)\b[^\n|&]*?\s-(?:c|e|r|E)\s+"
                         r"(?:\"([^\"]*)\"|'([^']*)'|(\S+))", text):
        check_code(m.group(1) or m.group(2) or m.group(3) or '', 'código inline', True)
    if re.search(r"\$['\"]", text):
        raise Block('aspas ANSI-C ($\'...\') bloqueadas (ofuscação de comando).')
    if re.search(r'/dev/(tcp|udp)/', text):
        raise Block('/dev/tcp e /dev/udp bloqueados (rede crua).')
    visible = re.sub(r"'[^'\"]*'", '', text)
    for m in re.finditer(r'\$\{?([A-Za-z_][A-Za-z0-9_]*|[0-9@*#!?$-])', visible):
        if m.group(1) not in ALLOWED_VARS:
            raise Block('expansão de variável $%s bloqueada (permitidas: %s).' % (m.group(1), ', '.join(sorted(ALLOWED_VARS))))
    if re.search(r'\bGIT_(CONFIG|SSH|ASKPASS|EXEC_PATH|DIR|WORK_TREE|PROXY|EXTERNAL)', text, re.I):
        raise Block('variável GIT_* de configuração/execução bloqueada.')
    unquoted = re.sub(r"'[^']*'|\"[^\"]*\"", '', text)
    if re.search(r'\{[^{}\s]*(,|\.\.)[^{}\s]*\}', unquoted):
        raise Block('expansão de chaves {a,b} bloqueada (monta nome de comando).')
    if re.search(r'\bawk\b', text) and re.search(r'system\s*\(|\|\s*getline|popen', text):
        raise Block('awk com system()/getline bloqueado.')
    for mode in ('strip', 'slash'):
        norm = normalize(text, mode)
        if mode == 'strip':
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


MCP_EXEMPT_SERVERS = {'memory', 'visualize', 'widgets'}
CLAUDE_AI_READ = {'current_time', 'approximate_location', 'image_search', 'read_research_report', 'us_election_info'}


def check_mcp(name):
    m = re.match(r'^mcp__(.+?)__(.+)$', name)
    if not m:
        return
    server, tool = m.group(1).lower(), m.group(2).lower()
    if server in MCP_EXEMPT_SERVERS or (server == 'claude_ai' and tool in CLAUDE_AI_READ):
        return
    write = re.search(r'(send|forward|reply|create|update|delete|trash|share|publish|schedule|execute|fire|upload|'
                      r'write|apply|label|spam|status|budget|add_repo|copy|move|resolve|upsert|insert|post|run|'
                      r'cancel|remember|declare|pin|watch|contact|use_|generate|set_|add_|click|type|fill|drag|'
                      r'navigate|press|select|handle|end_conversation|launch)', tool)
    read = re.search(r'(^|_)(get|list|search|read|download|describe|whoami|info|stats|query|fetch|recall|find|'
                     r'graph|check|metadata|screenshot|help|overview|callers|impact|imports|neighbors|rank|trace|'
                     r'tests_for|node|options|fields|connectors|display)(_|$)', tool)
    if write or not read:
        raise Block('ferramenta MCP bloqueada (%s/%s): só leituras (get/list/search/read/query) são permitidas; '
                    'escrita/publicação/navegação exige autorização do Japa.' % (server, tool))


# ---------------------------------------------------------------- agentes
def state_dir():
    d = os.environ.get('ROCHA_GUARD_STATE_DIR') or os.path.join(project_root(), '.claude', 'state')
    os.makedirs(d, exist_ok=True)
    return d


class Lock:
    """Serializa leitura-modificação-gravação do estado (hooks de agentes rodam em paralelo)."""

    def __enter__(self):
        self.f = open(os.path.join(state_dir(), 'lock'), 'w')
        try:
            import fcntl
            fcntl.flock(self.f, fcntl.LOCK_EX)
        except ImportError:  # Windows: sem flock; proteção de concorrência indisponível
            pass
        return self

    def __exit__(self, *a):
        self.f.close()


def load_state():
    try:
        with open(os.path.join(state_dir(), 'agents.json')) as f:
            st = json.load(f)
        if isinstance(st, dict) and isinstance(st.get('active'), list) and isinstance(st.get('cache'), dict):
            return st
        log('state', 'reset', 'agents.json com estrutura inválida; reiniciado')
    except FileNotFoundError:
        pass
    except Exception as e:
        log('state', 'reset', 'agents.json ilegível (%r); reiniciado' % e)
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
        if r.returncode != 0:
            return ''
        return r.stdout.strip() + hashlib.sha1(d.stdout.encode()).hexdigest()[:8]
    except Exception:
        return ''


def agent_key(ti, cwd):
    atype = ti.get('subagent_type') or 'general-purpose'
    prompt = re.sub(r'\s+', ' ', (ti.get('prompt') or '').lower()).strip()
    head = head_sha(cwd)
    return atype, hashlib.sha1((atype + '|' + prompt + '|' + head).encode()).hexdigest(), head


def max_agents():
    try:
        return max(1, int(os.environ.get('ROCHA_MAX_AGENTS', MAX_AGENTS_DEFAULT)))
    except ValueError:
        return MAX_AGENTS_DEFAULT


def agent_pre(p):
    ti = p.get('tool_input') or {}
    atype, key, head = agent_key(ti, p.get('cwd'))
    now = time.time()
    st = load_state()
    st['active'] = [a for a in st['active'] if isinstance(a, dict) and now - a.get('t', 0) < TTL_ACTIVE]
    st['cache'] = {k: v for k, v in st['cache'].items() if isinstance(v, dict) and now - v.get('t', 0) < TTL_CACHE}
    hit = st['cache'].get(key) if head else None   # sem HEAD confiável não há reaproveitamento
    if hit and os.environ.get('ROCHA_FORCE_REANALYSE') != '1':
        save_state(st)
        raise Block('Análise idêntica já concluída neste commit/estado (%s). Reutilize o resultado:\n%s'
                    % (hit.get('agent'), hit.get('summary', '')[:1500]))
    limit = max_agents()
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
    atype, key, head = agent_key(ti, p.get('cwd'))
    st = load_state()
    tid = p.get('tool_use_id')
    idx = next((i for i, a in enumerate(st['active']) if tid and a.get('id') == tid), None)
    if idx is None:
        idx = next((i for i, a in enumerate(st['active']) if a.get('key') == key), None)
    if idx is not None:
        st['active'].pop(idx)
    if head:
        st['cache'][key] = {'t': time.time(), 'agent': atype, 'summary': summarize(p.get('tool_response'))}
    save_state(st)


def agent_stop(p):
    st = load_state()
    at = p.get('agent_type') or ''
    idx = next((i for i, a in enumerate(st['active'])
                if at and (a.get('agent') == at or a.get('agent', '').endswith(':' + at) or at.endswith(':' + a.get('agent', '')))), None)
    matched = idx is not None
    if idx is None and st['active']:
        idx = 0      # sem correspondência: libera a vaga mais antiga, sem atribuir resultado
    if idx is not None:
        a = st['active'].pop(idx)
        msg = p.get('last_assistant_message')
        if msg and matched:
            st['cache'][a['key']] = {'t': time.time(), 'agent': a.get('agent'), 'summary': summarize(msg)}
    save_state(st)


# ---------------------------------------------------------------- main
def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ''
    if os.environ.get('ROCHA_GUARD_ADMIN') == '1':
        return 0
    try:
        p = json.load(sys.stdin)
        if not isinstance(p, dict):
            raise ValueError('payload não é objeto')
    except Exception as e:
        if mode.startswith('agent-'):
            return 0
        log(mode, 'error-closed', 'stdin inválido: %r' % e)
        sys.stderr.write('[rocha-guard] BLOQUEADO: entrada do hook ilegível (falha fechada).\n')
        return 2
    ti = p.get('tool_input') if isinstance(p.get('tool_input'), dict) else {}
    cwd = p.get('cwd') or os.getcwd()
    what = ''
    try:
        if mode == 'bash':
            what = ti.get('command') or ''
            if not isinstance(what, str) or not what.strip():
                raise Block('comando ausente/vazio (falha fechada).')
            check_bash(what, cwd)
        elif mode in ('write', 'read'):
            what = ti.get('file_path') or ti.get('notebook_path') or ti.get('path') or ''
            tool = p.get('tool_name', '')
            if mode == 'read':
                for extra in (ti.get('glob'), ti.get('pattern') if tool == 'Glob' else None):
                    if isinstance(extra, str) and CREDS.search(extra.replace('\\', '/').lower()):
                        raise Block('busca por arquivos de credencial bloqueada: %s' % extra[:60])
            if what:
                check_path(what, cwd, mode == 'write')
            elif mode == 'write' or tool not in ('Grep', 'Glob'):
                raise Block('caminho ausente (falha fechada).')
        elif mode == 'mcp':
            what = p.get('tool_name') or ''
            if not what:
                raise Block('tool_name ausente (falha fechada).')
            check_mcp(what)
        elif mode == 'agent-pre':
            what = ti.get('subagent_type', '')
            try:
                with Lock():
                    agent_pre(p)
            except Block:
                raise
            except Exception as e:  # consumo: falha aberta (registrada)
                log(mode, 'error-open', repr(e))
                return 0
        elif mode == 'agent-post':
            with Lock():
                agent_post(p)
        elif mode == 'agent-stop':
            with Lock():
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
