function []=crc_comm(infile_path, outfile_path)
    try
        % Divisor we'll use to get our remainders
        divisor = [1 1 1 1];
        divisor_bsize = numel(divisor);

        % Get binary data from file
        infile  = fopen(infile_path, 'r');
        data = fread(infile, [1, Inf], 'uint8');
        fclose(infile);
        bits = uint8(rem(floor((1 ./ [128, 64, 32, 16, 8, 4, 2, 1].') * data), 2));
        bits = bits(:);
        file_bsize = numel(bits);

        % We'll add a CRC after every packet
        % of n bits
        n = uint8(8);

        % Initialize an array with the size of
        % our (to be) coded message
        coded_size = idivide(file_bsize, n) * divisor_bsize + file_bsize;
        coded_rem = mod(file_bsize, n);
        if (coded_rem > 0)
            coded_size = coded_size + coded_rem + divisor_bsize;
        end
        out_mess = uint8.empty(0, coded_size);

        % Add CRC to our n bit packets
        while true
            % Get current packet
            inpacket = double(transpose(bits(1:n)));
            bits = bits(n+1:end);

            % Add the trailing remainder bits
            brem = binary_rem(inpacket, divisor);
            outpacket = [ inpacket brem ]

            if numel(bits) < n 
                % TODO: Handle last packet if it has
                % less than n bits
                break
            end
        end

    catch err
%        if strcmp(err.message, 'Not enough input arguments.')
%            fprintf('Usage: main <infile> <outfile> <divisor>\n')
%        else
            rethrow(err);
%        end
    end
end
