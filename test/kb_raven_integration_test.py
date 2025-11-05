import os
import random
import string
import tempfile
import unittest

from installed_clients.WorkspaceClient import Workspace
from installed_clients.ReadsUtilsClient import ReadsUtils
from installed_clients.AssemblyUtilClient import AssemblyUtil

from lib.kb_raven.kb_ravenImpl import kb_raven


def _rand_suffix(n=6):
    return ''.join(random.choice(string.ascii_lowercase + string.digits) for _ in range(n))


class RavenIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Read config from env / deploy.cfg-equivalent
        cls.ws_url = os.environ.get('KB_WORKSPACE_URL') or 'https://kbase.us/services/ws'
        cls.scratch = os.environ.get('KB_SCRATCH') or '/kb/module/work'
        os.makedirs(cls.scratch, exist_ok=True)

        # Clients (use callback env provided by kb-sdk test harness)
        cls.ws = Workspace(cls.ws_url)
        cls.ru = ReadsUtils(os.environ['SDK_CALLBACK_URL'])
        cls.au = AssemblyUtil(os.environ['SDK_CALLBACK_URL'])

        # Make a fresh test workspace
        cls.ws_name = f"kb_raven_it_{_rand_suffix()}"
        cls.ws.create_workspace({'workspace': cls.ws_name})

        # Impl under test
        cls.impl = kb_raven({'scratch': cls.scratch, 'workspace-url': cls.ws_url})

    @classmethod
    def tearDownClass(cls):
        try:
            cls.ws.delete_workspace({'workspace': cls.ws_name})
        except Exception:
            pass

    def _write_tiny_fastq(self, path):
        # Generate a few long-read-like sequences with overlaps
        # (Simple repeats; Raven should still produce some contigs with lenient params)
        reads = []
        core = ("ACGT" * 250) + ("GATTACA" * 50)  # ~1.45kb motif
        r1 = core + ("ACGT" * 100)
        r2 = ("ACGT" * 75) + core + ("ACGT" * 25)
        r3 = ("ACGT" * 50) + core + ("ACGT" * 50)
        for i, seq in enumerate([r1, r2, r3], start=1):
            reads.append(f"@read{i}\n{seq}\n+\n" + ("I" * len(seq)) + "\n")
        with open(path, "w") as fh:
            fh.write("".join(reads))

    def test_end_to_end_raven(self):
        # 1) Create a tiny single-end FASTQ on disk
        fq_path = os.path.join(self.scratch, f"tiny_{_rand_suffix()}.fastq")
        self._write_tiny_fastq(fq_path)

        # 2) Upload reads to workspace as a SingleEndLibrary
        up = self.ru.upload_reads({
            'wsname': self.ws_name,
            'sequencing_tech': 'ONT',
            'fwd_file': fq_path
        })
        reads_ref = up['obj_ref']

        # 3) Run Raven with lenient params for tiny data
        params = {
            'workspace_name': self.ws_name,
            'read_libraries': [reads_ref],
            'assembly_name': f"raven_asm_{_rand_suffix()}",
            'threads': 1,
            'polishing_rounds': 0,
            'kmer_len': 13,
            'window_len': 4,
            'frequency': 0.01,
            'identity': 0.0,
            'max_num_overlaps': 128,
            'min_unitig_size': 100,
            'write_gfa': 0,
            'resume': 0
        }
        out = self.impl.run_kb_raven(None, params)[0]

        # 4) Basic assertions
        self.assertIn('report_name', out)
        self.assertIn('report_ref', out)
        self.assertIn('assembly_ref', out)
        asm_ref = out['assembly_ref']

        # 5) Fetch the assembly FASTA back and ensure it's non-empty
        fa = self.au.get_assembly_as_fasta({'ref': asm_ref})
        fa_path = fa['path']
        self.assertTrue(os.path.isfile(fa_path), "Assembly FASTA file not found")
        # Has at least one contig header
        with open(fa_path) as fh:
            content = fh.read()
            self.assertIn('>', content, "FASTA appears empty or malformed")
