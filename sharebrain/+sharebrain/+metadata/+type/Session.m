classdef Session < nansen.metadata.type.Session
%Session - A NANSEN session with the state of its subject from the EBRAINS Knowledge Graph
%
%   The Knowledge Graph records values that change over time, such as age
%   and weight, on subject states (openMINDS SubjectState) rather than on
%   the subject, and a state describes the subject during the sessions it
%   applies to. This class adds the values of that state to the session.
%   sharebrain.importKGSubjects fills them.
%
%   Create the session table of a project with this class to have the
%   columns from the start:
%       nansen.config.initializeSessionTable(dataLocationModel, ...
%           @sharebrain.metadata.type.Session, SkipInteractiveSteps=true)
%
%   See also sharebrain.importKGSubjects, sharebrain.metadata.type.Subject

    properties (SetObservable)
        SubjectAge char           % Age of the subject, value and unit, e.g. '3 month'
        SubjectAgeCategory char   % Age category, e.g. 'adult'
        SubjectWeight char        % Weight of the subject, value or range and unit, e.g. '400-500 gram'
        SubjectAttributes char    % Attributes of the subject state, e.g. 'alive, awake'
        SubjectStateKGId char     % UUID of the openMINDS SubjectState in the Knowledge Graph
    end

    methods
        function obj = Session(varargin)
            obj@nansen.metadata.type.Session(varargin{:})
        end
    end
end
