function []=crc_comm(infile_path, outfile_path)
    try
        if (nargin ~= 2)
            fprintf('Usage: main <infile> <outfile>\n')
            return
        end

        % Divisor we'll use to get our remainders
        divisor = [1 1 1 1];
        divisor_bsize = numel(divisor);

        % Get binary data from file
        infile  = fopen(infile_path, 'r');
        data = fread(infile, [1, Inf], 'uint8');
        fclose(infile);
        bits = uint8(rem(floor((1 ./ [128, 64, 32, 16, 8, 4, 2, 1].') * data), 2));
        bits = bits(:);
        inmess = bits;
        file_bsize = numel(bits);

        % We'll add a CRC after every packet
        % of n bits
        n = uint8(7);
        outpacket_bsize = n + divisor_bsize;

        % Initialize an array with the size of
        % our (to be) coded message
        coded_size = idivide(file_bsize, n) * outpacket_bsize;
        coded_rem = mod(file_bsize, n);
        if (coded_rem > 0)
            coded_size = coded_size + coded_rem + divisor_bsize;
        end
        outmess = uint8.empty(0, coded_size);

        % Add CRC to our n bit packets
        counter = 0;
        while true
            % Get current packet
            inpacket = transpose(bits(1:n));
            bits = bits(n+1:end);

            % Add the trailing remainder bits
            brem = binary_rem(inpacket, divisor);
            outpacket = [ inpacket brem ];
            
            % Add the outpacket to outmess
            curr_index = counter*outpacket_bsize+1;
            outmess(curr_index:curr_index + outpacket_bsize - 1) = outpacket;

            counter = counter + 1;

            if numel(bits) < n 
                if numel(bits) > 0
                    % Handle last packet if it has
                    % less than n bits
                    inpacket = transpose(bits);

                    % Add the trailing remainder bits
                    brem = binary_rem(inpacket, divisor);
                    outpacket = [ inpacket brem ];
                    last_outpacket_bsize = numel(outpacket);

                    % Add the outpacket to outmess
                    curr_index = counter*outpacket_bsize+1;
                    outmess(curr_index:curr_index + last_outpacket_bsize - 1) = outpacket;
                end
                break
            end
        end

    catch err
        if strcmp(err.identifier, "MATLAB:FileIO:InvalidFid")
            error("Could not read from infile.");
        else
           rethrow(err);
        end
    end
end
