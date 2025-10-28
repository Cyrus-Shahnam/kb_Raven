# kb_raven/lib/kb_raven/kb_ravenImpl.py
# -*- coding: utf-8 -*-
import os
import subprocess
import logging
from typing import List, Dict

from installed_clients.AssemblyUtilClient import AssemblyUtil
from installed_clients.ReadsUtilsClient import ReadsUtils
from installed_clients.KBaseReportClient import KBaseReport

class kb_raven:
    VERSION = "0.0.1"
    GIT_URL = "https://github.com/your-org/kb_raven"
    GIT_COMMIT_HASH = "local"

    def __init__(self, config: Dict):
        self.cfg = config
        self.scratch = config['scratch']
        self.callback_url = os.environ.get('SDK_CALLBACK_URL')
        self.log = logging.getLogger('kb_raven')
        self.log.setLevel(logging.INFO)

    # ---------- helpers ----------
    @staticmethod
    def _compute_fasta_stats(fasta_path: str) -> Dict[str, int]:
        lengths = []
        n = 0
        with open(fasta_path, 'r') as fh:
            for line in fh:
                if not line:
                    continue
                if line[0] == '>':
                    if n > 0:
                        lengths.append(n)
                        n = 0
                else:
                    n += len(line.strip())
            if n > 0:
                lengths.append(n)
        if not lengths:
            return {"num_contigs": 0, "total_len": 0, "n50": 0}
        lengths.sort(reverse=True)
        total = sum(lengths)
        cum = 0
        n50 = 0
        half = total / 2.0
        for L in lengths:
            cum += L
            if cum >= half:
                n50 = L
                break
        return {"num_contigs": len(lengths), "total_len": total, "n50": n50}

    def _download_reads(self, ru: ReadsUtils, refs: List[str]) -> List[str]:
        inputs = []
        for ref in refs:
            ret = ru.download_reads({
                "read_libraries": [ref],
                "interleaved": 0
            })
            # SingleEnd libraries provide a "files" dict with "fwd"
            lib = list(ret['files'].values())[0]
            if 'fwd' in lib:
                inputs.append(lib['fwd'])
            elif 'files' in lib and 'fwd' in lib['files']:
                inputs.append(lib['files']['fwd'])
            else:
                raise ValueError(f"Unsupported reads structure for {ref}: {lib.keys()}")
        return inputs

    # ---------- method ----------
    def run_raven_assembler(self, ctx, params):
        """
        params:
          workspace_name (str)
          reads_refs (list<ref>)
          threads (int, optional)
          polishing_rounds (int, optional)
          identity (float, optional)
          frequency (float, optional)
          min_unitig_size (int, optional)
          save_gfa (bool, optional)
          assembly_name (str, optional)
        """
        wsname = params.get('workspace_name')
        if not wsname:
            raise ValueError("workspace_name is required")
        reads_refs = params.get('reads_refs') or []
        if not reads_refs:
            raise ValueError("At least one reads reference is required")

        threads = int(params.get('threads', 4) or 4)
        polishing = int(params.get('polishing_rounds', 2) or 2)
        identity = float(params.get('identity', 0) or 0)
        frequency = float(params.get('frequency', 0.001) or 0.001)
        min_unitig = int(params.get('min_unitig_size', 9999) or 9999)

        sg = str(params.get('save_gfa', '0')).strip().lower()
        save_gfa = sg in ('1', 'true', 'yes')
        min_unitig = int(params.get('min_unitig_size', 9999))
        asm_name = params.get('assembly_name') or 'Raven.Assembly'

        ru = ReadsUtils(self.callback_url)
        au = AssemblyUtil(self.callback_url)
        kbr = KBaseReport(self.callback_url)

        self.log.info("Downloading reads...")
        input_files = self._download_reads(ru, reads_refs)
        self.log.info(f"Input files: {input_files}")

        out_fa = os.path.join(self.scratch, "raven.contigs.fasta")
        gfa_path = os.path.join(self.scratch, "raven.graph.gfa") if save_gfa else None

        # Build raven command
        cmd = ["raven",
               "-t", str(threads),
               "-p", str(polishing),
               "-f", str(frequency),
               "-u", str(min_unitig)]
        if identity > 0:
            cmd += ["-i", str(identity)]
        if save_gfa:
            cmd += ["--graphical-fragment-assembly", gfa_path]
        cmd += input_files

        self.log.info(f"Running: {' '.join(cmd)}")
        with open(out_fa, "wb") as fasta_out:
            # Capture FASTA on stdout into file (raven writes to stdout by default)
            subprocess.run(cmd, check=True, stdout=fasta_out, stderr=subprocess.PIPE)

        stats = self._compute_fasta_stats(out_fa)

        self.log.info("Saving Assembly...")
        asm_ref = au.save_assembly_from_fasta({
            "file": {"path": out_fa},
            "workspace_name": wsname,
            "assembly_name": asm_name
        })

        # Prepare HTML report
        html = f"""
        <html><body>
        <h2>Raven assembly</h2>
        <table border="1" cellpadding="6">
          <tr><th>Assembly</th><td>{asm_name}</td></tr>
          <tr><th>Contigs</th><td>{stats['num_contigs']}</td></tr>
          <tr><th>Total length (bp)</th><td>{stats['total_len']}</td></tr>
          <tr><th>N50 (bp)</th><td>{stats['n50']}</td></tr>
          <tr><th>Threads</th><td>{threads}</td></tr>
          <tr><th>Polishing rounds</th><td>{polishing}</td></tr>
        </table>
        </body></html>
        """.strip()

        rep = kbr.create_extended_report({
            "workspace_name": wsname,
            "message": "Raven finished.",
            "direct_html": html,
            "objects_created": [{
                "ref": asm_ref,
                "description": "Raven assembly"
            }],
            "file_links": ([{
                "path": gfa_path,
                "name": "raven.graph.gfa",
                "label": "Assembly graph (GFA)"
            }] if save_gfa else [])
        })

        return [{
            "report_name": rep['name'],
            "report_ref": rep['ref'],
            "assembly_ref": asm_ref,
            "gfa_path": gfa_path if save_gfa else ""
        }]
