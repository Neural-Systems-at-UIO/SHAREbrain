classdef Subject < nansen.metadata.type.Subject
%Subject - A NANSEN subject linked to its subject in the EBRAINS Knowledge Graph
%
%   Adds to nansen.metadata.type.Subject the identifiers of the openMINDS
%   Subject that the Knowledge Graph lists for the dataset version, so a
%   row of a project's subject table can be traced back to it.
%   sharebrain.importKGSubjects fills these properties together with
%   BiologicalSex, Species and Strain.
%
%   The properties that change over time (age, weight) belong to subject
%   states and are held by sharebrain.metadata.type.Session.
%
%   See also sharebrain.importKGSubjects, sharebrain.metadata.type.Session

    properties (SetObservable)
        KGInstanceId char   % UUID of the openMINDS Subject in the Knowledge Graph
        KGLookupLabel char  % lookupLabel of the Subject in the Knowledge Graph
    end
end
