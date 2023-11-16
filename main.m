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
        n = uint8(8);
        outpacket_bsize = n + divisor_bsize;

        % Initialize an array with the size of
        % our (to be) coded message
        total_packets = idivide(file_bsize, n);
        coded_size = total_packets * outpacket_bsize;
        coded_rem = mod(file_bsize, n);
        last_outpacket_bsize = outpacket_bsize;
        if (coded_rem > 0)
            total_packets = total_packets + 1;
            last_outpacket_bsize = coded_rem + divisor_bsize;
            coded_size = coded_size + last_outpacket_bsize;
        end
        outmess = uint8(zeros(total_packets, outpacket_bsize));

        % Add CRC to our n bit packets
        packets_sent = 0;
        while true
            if packets_sent == total_packets - 1
                % Handle last packet differently
                inpacket = transpose(bits);

                % Add the trailing remainder bits
                brem = binary_rem(inpacket, divisor);
                outpacket = [ inpacket brem ];

                % Add the outpacket to outmess
                outmess(packets_sent+1, 1:last_outpacket_bsize) = outpacket;
                break
            end

            % Get current packet
            inpacket = transpose(bits(1:n));
            bits = bits(n+1:end);

            % Add the trailing remainder bits
            brem = binary_rem(inpacket, divisor);
            outpacket = [ inpacket brem ];
            
            % Add the outpacket to outmess
            outmess(packets_sent+1, :) = outpacket;

            packets_sent = packets_sent + 1;

        end

        display(outmess);
        % TODO: Introduce some noise in the form
        % of a chance of a bit being flipped in every package 


    catch err
        if strcmp(err.identifier, "MATLAB:FileIO:InvalidFid")
            error("Could not read from infile.");
        else
           rethrow(err);
        end
    end
end
