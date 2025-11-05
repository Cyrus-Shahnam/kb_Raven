module kb_raven {

    typedef string workspace_name;
    typedef string data_obj_ref;
    typedef string data_obj_name;

    typedef structure {
        workspace_name workspace_name;
        list<data_obj_ref> read_libraries;
        data_obj_name assembly_name;
        int threads;
        int kmer_len;
        int window_len;
        float frequency;
        float identity;
        int max_num_overlaps;
        int polishing_rounds;
        int min_unitig_size;
        int write_gfa;
        int resume;
    } RavenParams;

    typedef structure {
        string report_name;
        string report_ref;
        string assembly_ref;
        string gfa_shock_id;
    } RavenResult;

    funcdef run_kb_raven(RavenParams params) returns (RavenResult result);
};
