% [daqData,headCt] = FastFetch( myObj, streamID, start_scan, scan_ct, channel_subset, downsample_ratio )
%
%     Get MxN matrix of stream data.
%     M = scan_ct = max samples to fetch.
%     N = channel count...
%         If channel_subset is not specified, N = current
%         SpikeGLX save-channel subset.
%     Fetching starts at index start_scan.
%     Data are int16 type.
%
%     downsample_ratio is an integer (default = 1).
%
%     Also returns headCt = index of first timepoint in matrix.
%
%Edited by Jorrit Montijn - improved performance
%
function [mat,headCt] = FastFetch( s, streamID, start_scan, scan_ct, varargin )

    if( nargin < 4 )
        error( 'Fetch requires at least 4 arguments' );
    end

    if( ~isnumeric( start_scan ) || ~size( start_scan, 1 ) )
        error( 'Invalid scan_start parameter' );
    end

    if( ~isnumeric( scan_ct ) || ~size( scan_ct, 1 ) )
        error( 'Invalid scan_ct parameter' );
    end

   % ChkConn( s ); %saves a lot of time

    % subset has pattern id1#id2#...
    if( nargin >= 5 )
        subset = sprintf( '%d#', varargin{1} );
    else
        subset = sprintf( '%d#', GetSaveChans( s, streamID ) );
    end

    dwnsmp = 1;

    if( nargin >= 6 )

        dwnsmp = varargin{2};

        if( ~isnumeric( dwnsmp ) || length( dwnsmp ) > 1 )
            error( 'Downsample factor must be a single numeric value' );
        end
    end

    ok = CalinsNetMex( 'sendString', s.handle, ...
            sprintf( 'FETCH %d %ld %d %s %d\n', ...
            streamID, start_scan, scan_ct, subset, dwnsmp ) );

    line = CalinsNetMex( 'readLine', s.handle );

    if( strfind( line, 'ERROR' ) == 1 )
        error( line );
        return;
    end

    % cells       = strsplit( line );
    cells       = strread( line, '%s' );
    mat_dims	= [str2double(cells{2}) str2double(cells{3})];
    headCt      = str2double(cells{4});

    if( ~isnumeric( mat_dims ) || ~size( mat_dims, 2 ) )
        error( 'Invalid matrix dimensions.' );
    end

    mat = CalinsNetMex( 'readMatrix', s.handle, 'int16', mat_dims );

    % transpose
    mat = mat';

    ReceiveOK( s, 'FETCH' );
end
