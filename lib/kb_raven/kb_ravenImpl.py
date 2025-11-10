# -*- coding: utf-8 -*-
#BEGIN_HEADER
import os
import subprocess
import shlex
import sys, json
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
    
    '''

    ######## WARNING FOR GEVENT USERS ####### noqa
    # Since asynchronous IO can lead to methods - even the same method -
    # interrupting each other, you must be *very* careful when using global
    # state. A method could easily clobber the state set by another while
    # the latter method is running.
    ######################################### noqa
    VERSION = "0.0.1"
    GIT_URL = "https://github.com/Cyrus-Shahnam/kb_Raven.git"
    GIT_COMMIT_HASH = "9a7ce84b87cb7b5bfd50e20c73c9a39d2064e789"

    #BEGIN_CLASS_HEADER
    #END_CLASS_HEADER

    # config contains contents of config file in a hash or None if it couldn't
    # be found
    #BEGIN_CONSTRUCTOR
    def __init__(self, config):
        # tolerate missing config (e.g., if KB_DEPLOYMENT_CONFIG isn't set)
        cfg = config or {}
        self.callback_url = os.environ.get('SDK_CALLBACK_URL')

        scratch = cfg.get('scratch') or os.environ.get('KB_SCRATCH') or '/kb/module/work'
        os.makedirs(scratch, exist_ok=True)
        self.scratch = os.path.abspath(scratch)

        self.ru = ReadsUtils(self.callback_url)
        self.au = AssemblyUtil(self.callback_url)
        self.dfu = DataFileUtil(self.callback_url)
        self.kbr = KBaseReport(self.callback_url)
    #END_CONSTRUCTOR

        pass


    def run_kb_raven(self, ctx, params):
        """
        :param params: instance of type "RavenParams" -> structure: parameter
           "workspace_name" of type "workspace_name", parameter
           "read_libraries" of list of type "data_obj_ref", parameter
           "assembly_name" of type "data_obj_name", parameter "threads" of
           Long, parameter "kmer_len" of Long, parameter "window_len" of
           Long, parameter "frequency" of Double, parameter "identity" of
           Double, parameter "max_num_overlaps" of Long, parameter
           "polishing_rounds" of Long, parameter "min_unitig_size" of Long,
           parameter "write_gfa" of Long, parameter "resume" of Long
        :returns: instance of type "RavenResult" -> structure: parameter
           "report_name" of String, parameter "report_ref" of String,
           parameter "assembly_ref" of String, parameter "gfa_shock_id" of
           String
        """
        # ctx is the context object
        # return variables are: result
        def run_kb_raven(self, ctx, params):
        print("[kb_raven] ENTER run_kb_raven()")
        print("[kb_raven] params keys:", list(params.keys()) if isinstance(params, dict) else type(params))
        sys.stdout.flush()
        # ...

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

        # At some point might do deeper type checking...
        if not isinstance(result, dict):
            raise ValueError('Method run_kb_raven return value ' +
                             'result is not type dict as required.')
        # return the results
        return [result]
    def status(self, ctx):
        #BEGIN_STATUS
        returnVal = {'state': "OK",
                     'message': "",
                     'version': self.VERSION,
                     'git_url': self.GIT_URL,
                     'git_commit_hash': self.GIT_COMMIT_HASH}
        #END_STATUS
        return [returnVal]
