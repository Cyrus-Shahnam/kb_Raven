/*
 * KBase service specification for Raven assembler wrapper
 */
module kb_raven {
    typedef string workspace_name;
    typedef string data_obj_ref;

    typedef structure {
        workspace_name workspace_name;
        list<data_obj_ref> reads_refs;   // One or more long-read libraries (ONT/PacBio), SingleEnd
        int threads;
        int polishing_rounds;
        float identity;
        float frequency;
        int min_unitig_size;
        bool save_gfa;
        string assembly_name;
    } RunRavenParams;

    typedef structure {
        string report_name;
        string report_ref;
        string assembly_ref;
        string gfa_path; // optional, only if save_gfa
    } RunRavenResult;

    funcdef run_raven_assembler(RunRavenParams params) returns (RunRavenResult);
};
