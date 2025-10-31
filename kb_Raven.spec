module kb_raven {
    typedef string workspace_name;
    typedef string workspace_id;
    typedef string data_obj_ref;
    typedef int    bool;

    typedef structure {
        workspace_name     workspace_name;
        workspace_id       workspace_id;
        list<data_obj_ref> reads_refs;
        string             assembly_name;
        int                threads;
        int                save_gfa;
    } RunRavenParams;

    typedef structure {
        string report_name;
        string report_ref;
    } RunRavenResult;

    funcdef run_raven_assembler(RunRavenParams params) returns (RunRavenResult);
};
