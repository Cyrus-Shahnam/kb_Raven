# -*- coding: utf-8 -*-
import os, subprocess, logging

from installed_clients.ReadsUtilsClient import ReadsUtils
from installed_clients.AssemblyUtilClient import AssemblyUtil
from installed_clients.KBaseReportClient import KBaseReport

class kb_raven:
    VERSION = "0.0.1"
    GIT_URL = "https://github.com/your-org/kb_raven"
    GIT_COMMIT_HASH = "local"

    def __init__(self, config):
        self.scratch = config['scratch']
        self.callback = os.environ.get('SDK_CALLBACK_URL')
        self.log = logging.getLogger('kb_raven'); self.log.setLevel(logging.INFO)

    def _dl(self, refs):
        ru = ReadsUtils(self.callback)
        files = []
        for ref in refs:
            ret = ru.download_reads({"read_libraries":[ref], "interleaved":0})
            lib = list(ret['files'].values())[0]
            if 'fwd' in lib: files.append(lib['fwd'])
            elif 'files' in lib and 'fwd' in lib['files']: files.append(lib['files']['fwd'])
            else: raise ValueError(f"Unsupported reads structure for {ref}: {lib.keys()}")
        return files

    def _stats(self, fasta):
        L=[]; n=0
        with open(fasta) as fh:
            for line in fh:
                if line.startswith('>'):
                    if n: L.append(n); n=0
                else:
                    n += len(line.strip())
        if n: L.append(n)
        if not L: return {"num":0,"tot":0,"n50":0}
        L.sort(reverse=True); tot=sum(L); half=tot/2; c=0; n50=0
        for x in L:
            c+=x
            if c>=half: n50=x; break
        return {"num":len(L),"tot":tot,"n50":n50}

    def run_raven_assembler(self, ctx, params):
        wsname = params.get('workspace_name')
        reads_refs = params.get('reads_refs') or []
        asm_name = params.get('assembly_name') or 'Raven.Assembly'
        threads = int(params.get('threads', 4) or 4)
        save_gfa = str(params.get('save_gfa', '0')).strip().lower() in ('1','true','yes')

        if not wsname: raise ValueError("workspace_name is required")
        if not reads_refs: raise ValueError("reads_refs is required")

        inputs = self._dl(reads_refs)
        out_fa = os.path.join(self.scratch, "raven.contigs.fasta")
        gfa = os.path.join(self.scratch, "raven.graph.gfa") if save_gfa else None

        cmd = ["raven", "-t", str(threads)] + inputs
        if save_gfa: cmd += ["--graphical-fragment-assembly", gfa]
        with open(out_fa, "wb") as out:
            subprocess.run(cmd, check=True, stdout=out, stderr=subprocess.PIPE)

        au = AssemblyUtil(self.callback)
        asm_ref = au.save_assembly_from_fasta({
            "file": {"path": out_fa},
            "workspace_name": wsname,
            "assembly_name": asm_name
        })

        stats = self._stats(out_fa)
        html = f"""<html><body><h3>Raven assembly</h3>
        <table border="1" cellpadding="6">
          <tr><th>Assembly</th><td>{asm_name}</td></tr>
          <tr><th>Contigs</th><td>{stats['num']}</td></tr>
          <tr><th>Total length (bp)</th><td>{stats['tot']}</td></tr>
          <tr><th>N50 (bp)</th><td>{stats['n50']}</td></tr>
        </table></body></html>"""

        kbr = KBaseReport(self.callback)
        rep = kbr.create_extended_report({
            "workspace_name": wsname,
            "message": "Raven finished.",
            "direct_html": html,
            "objects_created": [{"ref": asm_ref, "description": "Raven assembly"}],
            "file_links": ([{"path": gfa, "name": "raven.graph.gfa", "label": "Assembly graph (GFA)"}] if save_gfa else [])
        })
        return [{"report_name": rep["name"], "report_ref": rep["ref"]}]
