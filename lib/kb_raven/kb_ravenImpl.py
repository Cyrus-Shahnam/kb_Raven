# -*- coding: utf-8 -*-
#BEGIN_HEADER
import os
import subprocess
import shlex
from typing import List, Dict

from installed_clients.ReadsUtilsClient import ReadsUtils
from installed_clients.AssemblyUtilClient import AssemblyUtil
from installed_clients.DataFileUtilClient import DataFileUtil
from installed_clients.KBaseReportClient import KBaseReport
#END_HEADER


class kb_raven:
    """
    Raven long-read assembler for KBase
    """

    VERSION = "0.0.1"
    GIT_URL = "https://github.com/yourorg/kb_raven"
    GIT_COMMIT_HASH = "local"

    #BEGIN_CLASS_HEADER
    #END_CLASS_HEADER

    #BEGIN_CONSTRUCTOR
    def __init__(self, config):
        self.callback_url = os.environ.get('SDK_CALLBACK_URL')
        self.scratch = os.path.abspath(config['scratch'])
        self.ru = ReadsUtils(self.callback_url)
        self.au = AssemblyUtil(self.callback_url)
        self.dfu = DataFileUtil(self.callback_url)
        self.kbr = KBaseReport(self.callback_url)
    #END_CONSTRUCTOR

    #BEGIN run_kb_raven
    def run_kb_raven(self, ctx, params):
        """
        params:
          - workspace_name (str)
          - read_libraries (list<ref>)
          - assembly_name (str)
          - threads (int)
          - polishing_rounds (int)
          - kmer_len (int)
          - window_len (int)
          - frequency (float)
          - identity (float)
          - max_num_overlaps (int)
          - min_unitig_size (int)
          - write_gfa (0/1)
          - resume (0/1)
        """
        ws_name = params['workspace_name']
        reads_refs = params['read_libraries']
        out_name = params['assembly_name']

        # Defaults consistent with display/spec
        threads = int(params.get('threads') or 8)
        pol = int(params.get('polishing_rounds') or 2)
        kmer = int(params.get('kmer_len') or 15)
        win = int(params.get('window_len') or 5)
        freq = float(params.get('frequency') or 0.001)
        ident = float(params.get('identity') or 0.0)
        maxovl = int(params.get('max_num_overlaps') or 32)
        minunitig = int(params.get('min_unitig_size') or 9999)
        write_gfa = int(params.get('write_gfa') or 0)
        resume = int(params.get('resume') or 0)

        # 1) Download reads
        dl = self.ru.download_reads({'read_libraries': reads_refs, 'interleaved': 'false'})
        input_fastx: List[str] = []
        for ref, meta in dl['files'].items():
            # Single-end long reads -> use fwd files list
            fwd_list = meta['files'].get('fwd', [])
            if fwd_list:
                input_fastx.extend(fwd_list)
        if not input_fastx:
            raise ValueError("No input FASTQ/FASTA files were found in provided libraries.")

        work = os.path.join(self.scratch, 'raven_work')
        os.makedirs(work, exist_ok=True)
        contigs_fa = os.path.join(work, 'assembly.fasta')
        gfa_path = os.path.join(work, 'assembly.gfa') if write_gfa else None

        # 2) Build Raven command
        cmd = [
            "raven",
            "-t", str(threads),
            "-p", str(pol),
            "-k", str(kmer),
            "-w", str(win),
            "-f", str(freq),
            "-i", str(ident),
            "-o", str(maxovl),
            "-u", str(minunitig)
        ]
        if resume:
            cmd.append("--resume")
        if write_gfa:
            cmd.extend(["--graphical-fragment-assembly", gfa_path])

        # Append all input files
        cmd.extend(input_fastx)

        # Raven prints FASTA to stdout – redirect to file
        cmdline = "{} > {}".format(' '.join(map(shlex.quote, cmd)), shlex.quote(contigs_fa))
        self._run_cmd(cmdline, cwd=work)

        # 3) Save Assembly object
        asm_ref = self.au.save_assembly_from_fasta({
            'file': {'path': contigs_fa},
            'assembly_name': out_name,
            'workspace_name': ws_name
        })

        # 4) Prepare report
        report_files = []
        if write_gfa and os.path.isfile(gfa_path):
            shock = self.dfu.file_to_shock({'file_path': gfa_path, 'make_handle': 0})
            report_files.append({
                'name': os.path.basename(gfa_path),
                'description': 'Raven assembly graph (GFA)',
                'shock_id': shock['shock_id']
            })

        html_link = None
        report_text = [
            f"Raven finished.",
            f"Input libraries: {len(reads_refs)}",
            f"Threads: {threads}, Polishing rounds: {pol}",
            f"K: {kmer}, W: {win}, f: {freq}, identity: {ident}, max overlaps: {maxovl}, min unitig: {minunitig}",
            f"Assembly object: {out_name}"
        ]

        rep = self.kbr.create_extended_report({
            'message': '\n'.join(report_text),
            'objects_created': [{'ref': asm_ref, 'description': 'Raven assembly'}],
            'file_links': report_files,
            'direct_html_link_index': 0 if html_link else None,
            'html_links': [html_link] if html_link else [],
            'workspace_name': ws_name
        })

        return [{
            'report_name': rep['name'],
            'report_ref': rep['ref'],
            'assembly_ref': asm_ref,
            'gfa_shock_id': report_files[0]['shock_id'] if report_files else ''
        }]
    #END run_kb_raven

    #BEGIN _run_cmd
    def _run_cmd(self, cmdline: str, cwd: str = None):
        proc = subprocess.run(cmdline, shell=True, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if proc.returncode != 0:
            raise RuntimeError(f"Command failed ({proc.returncode}):\n{cmdline}\nSTDOUT:\n{proc.stdout}\nSTDERR:\n{proc.stderr}")
        return proc
    #END _run_cmd
