import os
import shutil
import tempfile
import unittest

from lib.kb_raven.kb_ravenImpl import kb_raven


class _StubReadsUtils:
    def __init__(self, *a, **k):
        pass

    # Mimic ReadsUtils.download_reads() return structure
    def download_reads(self, params):
        # Create a tiny FASTQ to satisfy the wrapper (we won’t actually assemble it)
        tmp = params.get('_tmp_dir', tempfile.mkdtemp())
        fq = os.path.join(tmp, "tiny.fastq")
        with open(fq, "w") as fh:
            fh.write("@r1\nACGTACGTACGT\n+\nFFFFFFFFFFFF\n")
        return {"files": {"fake/ref": {"files": {"fwd": [fq]}}}}


class _StubAssemblyUtil:
    def __init__(self, *a, **k):
        pass

    def save_assembly_from_fasta(self, params):
        # Assert the wrapper actually wrote a contigs file
        path = params["file"]["path"]
        assert os.path.isfile(path), f"Contigs FASTA not found: {path}"
        return "123/45/6"  # fake ref


class _StubDataFileUtil:
    def __init__(self, *a, **k):
        pass

    def file_to_shock(self, params):
        return {"shock_id": "fake_shock_id"}


class _StubReport:
    def __init__(self, *a, **k):
        pass

    def create_extended_report(self, params):
        return {"name": "raven_report", "ref": "123/7/9"}


class RavenSmokeTest(unittest.TestCase):

    def setUp(self):
        # Minimal config – scratch is required
        self.scratch = tempfile.mkdtemp(prefix="kb_raven_test_")
        self.impl = kb_raven({"scratch": self.scratch})

        # Inject stubs for installed clients
        self.impl.ru = _StubReadsUtils()
        self.impl.au = _StubAssemblyUtil()
        self.impl.dfu = _StubDataFileUtil()
        self.impl.kbr = _StubReport()

        # Replace _run_cmd so we don't actually execute raven; instead, write a tiny FASTA
        def fake_run(cmdline, cwd=None):
            # Find the output redirection target after ">"
            if ">" not in cmdline:
                raise AssertionError("Expected shell redirection to contigs FASTA")
            out_fa = cmdline.split(">")[-1].strip().strip("'").strip('"')
            with open(out_fa, "w") as fh:
                fh.write(">contig1\nACGTACGTACGT\n")
            class P:  # mimic subprocess.CompletedProcess a bit
                returncode = 0
                stdout = "stub\n"
                stderr = ""
            return P()
        self.impl._run_cmd = fake_run

    def tearDown(self):
        shutil.rmtree(self.scratch, ignore_errors=True)

    def test_raven_smoke(self):
        params = {
            "workspace_name": "fake_ws",
            "read_libraries": ["123/1/1"],  # any ref; we stub download_reads anyway
            "assembly_name": "raven_asm",
            "threads": 2,
            "polishing_rounds": 0,
            "kmer_len": 15,
            "window_len": 5,
            "frequency": 0.001,
            "identity": 0.0,
            "max_num_overlaps": 32,
            "min_unitig_size": 1000,
            "write_gfa": 1,
            "resume": 0
        }
        # Provide temp dir to the stubbed ReadsUtils
        self.impl.ru._tmp_dir = self.scratch

        ret = self.impl.run_kb_raven(None, params)
        self.assertTrue(isinstance(ret, list) and len(ret) == 1)
        out = ret[0]
        self.assertIn("report_name", out)
        self.assertIn("report_ref", out)
        self.assertIn("assembly_ref", out)
        # GFA is optional but present here because write_gfa=1
        self.assertIn("gfa_shock_id", out)


if __name__ == "__main__":
    unittest.main()
