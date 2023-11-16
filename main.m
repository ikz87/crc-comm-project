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
        packet_bsize = n + divisor_bsize;

        % Initialize an array with the size of
        % our (to be) coded message
        total_packets = idivide(file_bsize, n);
        coded_size = total_packets * packet_bsize;
        coded_rem = mod(file_bsize, n);
        last_packet_bsize = packet_bsize;
        if (coded_rem > 0)
            total_packets = total_packets + 1;
            last_packet_bsize = coded_rem + divisor_bsize;
            coded_size = coded_size + last_packet_bsize;
        end
        coded_mess = uint8(zeros(total_packets, packet_bsize));

        % Add CRC to our n bit packets
        packets_coded = 0;
        while true
            if packets_coded == total_packets - 1
                % Handle last packet differently
                data = transpose(bits);

                % Add the trailing remainder bits
                brem = binary_rem(data, divisor);
                curr_packet = [ data brem ];

                % Add the curr_packet to coded_mess
                coded_mess(packets_coded+1, 1:last_packet_bsize) = curr_packet;
                break
            end

            % Get current packet
            data = transpose(bits(1:n));
            bits = bits(n+1:end);

            % Add the trailing remainder bits
            brem = binary_rem(data, divisor);
            curr_packet = [ data brem ];
            
            % Add the curr_packet to coded_mess
            coded_mess(packets_coded+1, :) = curr_packet;

            packets_coded = packets_coded + 1;

        end

        % At this point, we have a matrix coded_mess
        % with its rows being the coded packets
        % of our original file.
        % We'll transmit this matrix packet by packet
        % with a (simulated) random chance for 
        % every bit to be flipped
        
        transmitted_mess = uint8(zeros(total_packets, packet_bsize));
        flip_for_one_in = 10;
        packets_sent = 0;
        while true
            if packets_sent == total_packets - 1
                % Handle last packet differently
                curr_packet = coded_mess(packets_sent+1, :);
                data = curr_packet(1:last_packet_bsize-divisor_bsize);
                brem = curr_packet(last_packet_bsize-divisor_bsize+1:last_packet_bsize);

                if (brem == binary_rem(data, divisor))
                    fprintf("Got packet %d with no errors.\n", packets_sent+1);
                    break
                else
                    fprintf("Error detected in packet %d. Retrying transmission...\n", packets_sent+1);
                end
            end

            % Get current packet
            curr_packet = coded_mess(packets_sent+1, :);

            % Potentially flip a bit
            for i = 1:packet_bsize
                if (randi([1 flip_for_one_in]) == 1)
                    curr_packet(i) = uint8(~curr_packet(i));
                end
            end

            % Check packet integrity with CRC
            data = curr_packet(1:packet_bsize-divisor_bsize);
            brem = curr_packet(end-divisor_bsize+1:end);

            if (brem == binary_rem(data, divisor))
                fprintf("Got packet %d with no errors.\n", packets_sent+1);
                packets_sent = packets_sent+1;
            else
                fprintf("Error detected in packet %d. Retrying transmission...\n", packets_sent+1);
            end
        end

        %TODO: Add decoding logic and write output file

    catch err
        if strcmp(err.identifier, "MATLAB:FileIO:InvalidFid")
            error("Could not read from infile.");
        else
           rethrow(err);
        end
    end
end
