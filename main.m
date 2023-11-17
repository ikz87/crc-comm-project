function []=crc_comm(infile_path, outfile_path)
    try
        if (nargin ~= 2)
            fprintf('Usage: main <infile> <outfile>\n')
            return
        end
        
        outfile = fopen(outfile_path, 'w');
        infile  = fopen(infile_path, 'r');
        % Check if the file was opened successfully
        if (outfile == -1)
            error('Could not open outfile for writing.');
        elseif (infile == -1)
            error('Could not open infile for reading');
        end

        % Divisor we'll use to get our remainders
        divisor = [1 0 0 0 1 1 1];
        divisor_bsize = numel(divisor);

        % Get binary data from file
        data = fread(infile, [1, Inf], 'uint8');
        fclose(infile);
        bits = uint8(rem(floor((1 ./ [128, 64, 32, 16, 8, 4, 2, 1].') * data), 2));
        bits = bits(:);
        message = transpose(bits);
        message_bsize = numel(bits);

        % We'll add a CRC after every packet
        % of n bits
        n = 256;
        packet_bsize = n + divisor_bsize;

        % Initialize an array with the size of
        % our (to be) coded message
        total_packets = floor(message_bsize/n);
        coded_size = total_packets * packet_bsize;
        coded_rem = mod(message_bsize, n);
        last_packet_bsize = packet_bsize;
        if (coded_rem > 0)
            total_packets = total_packets + 1;
            last_packet_bsize = coded_rem + divisor_bsize;
            coded_size = coded_size + last_packet_bsize;
        end
        coded_mess = zeros(total_packets, packet_bsize);

        % Add CRC to our n bit packets
        packets_coded = 0;
        while true
            fprintf("Coding packet %d of %d...\n", packets_coded, total_packets);
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
        
        received_mess = zeros(1,message_bsize);
        flip_for_one_in = 1000;
        packets_sent = 0;
        while true
            if packets_sent == total_packets - 1
                % Handle last packet differently
                curr_packet = coded_mess(packets_sent+1, :);

                % Potentially flip bits
                for i = 1:packet_bsize
                    if (randi([1 flip_for_one_in]) == 1)
                        curr_packet(i) = ~curr_packet(i);
                    end
                end

                data = curr_packet(1:last_packet_bsize-divisor_bsize);
                brem = curr_packet(last_packet_bsize-divisor_bsize+1:last_packet_bsize);

                % Check packet integrity with CRC
                if (brem == binary_rem(data, divisor))
                    fprintf("CRC matches for packet %d\n", packets_sent+1);
                    received_mess(end-coded_rem+1:end) = data;
                    break
                else
                    fprintf("Error detected in packet %d. Retrying transmission...\n", packets_sent+1);
                end
            else
                % Get current packet
                curr_packet = coded_mess(packets_sent+1, :);

                % Potentially flip bits
                for i = 1:packet_bsize
                    if (randi([1 flip_for_one_in]) == 1)
                        curr_packet(i) = ~curr_packet(i);
                    end
                end

                % Check packet integrity with CRC
                data = curr_packet(1:packet_bsize-divisor_bsize);
                brem = curr_packet(end-divisor_bsize+1:end);

                if (brem == binary_rem(data, divisor))
                    fprintf("CRC matches for packet %d\n", packets_sent+1);
                    received_mess(n*packets_sent+1:n*(packets_sent+1)) = data;
                    packets_sent = packets_sent+1;
                else
                    fprintf("Error detected in packet %d. Retrying transmission...\n", packets_sent+1);
                end
            end
        end


        % Now we have an array received_mess which should contain the
        % same bits as our original message.
        % Let's write this array to the outfile
        for i = 1:8:numel(received_mess)
            fprintf("Copying decoded byte %d of %d...\n", (i-1)/8+1, numel(received_mess)/8);
            uint8_value = uint8(bi2de(received_mess(i:i+7), 'left-msb'));
            fwrite(outfile, uint8_value, 'uint8');
        end
        fclose(outfile);
        fprintf("Done\n");

        % Show efficiency of the system:
        % BER
        [number,ratio] = biterr(received_mess, message);
        fprintf("%d errors in decoded message (%f per million bits)\n", number, ratio*1000000);
        
        % Eye pattern
        time_vector = (0:length(received_mess)-1).';
        eyediagram(received_mess, 2);
        title('Eye Diagram');

    catch err
        if strcmp(err.identifier, "MATLAB:FileIO:InvalidFid")
            error("Invalid infile");
        else
           rethrow(err);
        end
    end
end
