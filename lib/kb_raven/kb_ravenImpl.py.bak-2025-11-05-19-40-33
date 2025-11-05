# -*- coding: utf-8 -*-
#BEGIN_HEADER
import os
import subprocess
import shlex
from typing import List

from installed_clients.ReadsUtilsClient import ReadsUtils
from installed_clients.AssemblyUtilClient import AssemblyUtil
from installed_clients.DataFileUtilClient import DataFileUtil
try:
    from installed_clients.KBaseReportClient import KBaseReport
except ImportError:
    from KBaseReport.KBaseReportClient import KBaseReport
#END_HEADER


class kb_raven:
    '''
    Module Name:
    kb_raven

    Module Description:
    Raven long-read assembler for KBase
    '''

    #BEGIN_CLASS_HEADER
    #END_CLASS_HEADER

    def __init__(self, config):
        #BEGIN_CONSTRUCTOR
        self.callback_url = os.environ.get('SDK_CALLBACK_URL')
        self.scratch = os.path.abspath(config['scratch'])
        self.ru = ReadsUtils(self.callback_url)
        self.au = AssemblyUtil(self.callback_url)
        self.dfu = DataFileUtil(self.callback_url)
        self.kbr = KBaseReport(self.callback_url)
        #END_CONSTRUCTOR
        pass

    def run_kb_raven(self, ctx, params):
        """
        Run Raven on long-read libraries and save a KBase Assembly.
        """
        #BEGIN run_kb_raven
        ws_name = params['workspace_name']
        reads_refs = params['read_libraries']
        out_name = params['assembly_name']

        threads = int(params.get('threads', 8))
        pol = int(params.get('polishing_rounds', 2))
        kmer = int(params.get('kmer_len', 15))
        win = int(params.get('window_len', 5))
        freq = float(params.get('frequency', 0.001))
        ident = float(params.get('identity', 0.0))
        maxovl = int(params.get('max_num_overlaps', 32))
        minunitig = int(params.get('min_unitig_size', 9999))
        write_gfa = int(params.get('write_gfa', 0))
        resume = int(params.get('resume', 0))

        # 1) Download reads
        dl = self.ru.download_reads({'read_libraries': reads_refs, 'interleaved': 'false'})
        input_fastx: List[str] = []
        for _, meta in dl['files'].items():
            fwd = meta['files'].get('fwd', [])
            if fwd:
                input_fastx.extend(fwd)
        if not input_fastx:
            raise ValueError("No input FASTA/FASTQ files found in provided libraries.")

        # 2) Run Raven
        work = os.path.join(self.scratch, 'raven_work')
        os.makedirs(work, exist_ok=True)
        contigs_fa = os.path.join(work, 'assembly.fasta')
        gfa_path = os.path.join(work, 'assembly.gfa') if write_gfa else None

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
        cmd.extend(input_fastx)

        # Raven writes contigs to stdout -> redirect to file
        cmdline = "{} > {}".format(' '.join(shlex.quote(c) for c in cmd), shlex.quote(contigs_fa))
        self._run_cmd(cmdline, cwd=work)

        # 3) Save Assembly
        asm_ref = self.au.save_assembly_from_fasta({
            'file': {'path': contigs_fa},
            'assembly_name': out_name,
            'workspace_name': ws_name
        })

        # 4) Report
        file_links = []
        if write_gfa and os.path.isfile(gfa_path):
            shock = self.dfu.file_to_shock({'file_path': gfa_path, 'make_handle': 0})
            file_links.append({
                'name': os.path.basename(gfa_path),
                'description': 'Raven assembly graph (GFA)',
                'shock_id': shock['shock_id']
            })

        rep = self.kbr.create_extended_report({
            'message': '\n'.join([
                'Raven finished.',
                f'Input libraries: {len(reads_refs)}',
                f'Threads: {threads}, Polishing rounds: {pol}',
                f'K: {kmer}, W: {win}, f: {freq}, identity: {ident}, max overlaps: {maxovl}, min unitig: {minunitig}',
                f'Assembly object: {out_name}'
            ]),
            'objects_created': [{'ref': asm_ref, 'description': 'Raven assembly'}],
            'file_links': file_links,
            'workspace_name': ws_name
        })

        return [{
            'report_name': rep['name'],
            'report_ref': rep['ref'],
            'assembly_ref': asm_ref,
            'gfa_shock_id': file_links[0]['shock_id'] if file_links else ''
        }]
        #END run_kb_raven

    #BEGIN _run_cmd
    def _run_cmd(self, cmdline: str, cwd: str = None):
        proc = subprocess.run(
            cmdline, shell=True, cwd=cwd,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
        if proc.returncode != 0:
            raise RuntimeError(
                f"Command failed ({proc.returncode}):\n{cmdline}\nSTDOUT:\n{proc.stdout}\nSTDERR:\n{proc.stderr}"
            )
        return proc
    #END _run_cmd
