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
        coded_signal = zeros(total_packets, packet_bsize);

        % Add CRC to our n bit packets
        packets_coded = 0;
        while true
            fprintf("\rCoding packet %d of %d...", packets_coded, total_packets);
            if packets_coded == total_packets - 1
                % Handle last packet differently
                data = transpose(bits);

                % Add the trailing remainder bits
                brem = binary_rem(data, divisor);
                curr_packet = [ data brem ];

                % Add the curr_packet to coded_signal
                coded_signal(packets_coded+1, 1:last_packet_bsize) = curr_packet;
                break
            end

            % Get current packet
            data = transpose(bits(1:n));
            bits = bits(n+1:end);

            % Add the trailing remainder bits
            brem = binary_rem(data, divisor);
            curr_packet = [ data brem ];
            
            % Add the curr_packet to coded_signal
            coded_signal(packets_coded+1, :) = curr_packet;

            packets_coded = packets_coded + 1;

        end
        fprintf("\rAll packets coded.                  \n");

        % At this point, we have a matrix coded_signal
        % with its rows being the coded packets
        % of our original file.
        % We'll transmit this matrix packet by packet
        % with PSK mod
        
        SNR = 6.5;
        M = 2;
        received_signal = zeros(total_packets*packet_bsize,1);
        received_signal_no_crc = zeros(1,total_packets*packet_bsize);
        received_mess = zeros(1,message_bsize);
        received_mess_no_crc = zeros(1,message_bsize);

        packets_sent = 0;
        failed_packet_transmissions = 0;
        fprintf("Starting transmission over PSK with SNR = %f.\n", SNR);
        while true
            if packets_sent == total_packets - 1
                % Handle last packet differently
                curr_packet = coded_signal(packets_sent+1, :);

                % Transmit it with PSK mod
                modulated_packet = pskmod(curr_packet, M);
                received_packet = awgn(modulated_packet, SNR);
                demodulated_packet = pskdemod(received_packet, M);

                data = demodulated_packet(1:last_packet_bsize-divisor_bsize);
                brem = demodulated_packet(last_packet_bsize-divisor_bsize+1:last_packet_bsize);

                % Check packet integrity with CRC
                if (brem == binary_rem(data, divisor))
                    fprintf("\rCRC matches for packet %d of", packets_sent+1, total_packets);
                    received_mess(end-coded_rem+1:end) = data;
                    received_signal(packets_sent*packet_bsize+1:(packets_sent+1)*packet_bsize) = received_packet;
                    if received_signal_no_crc(packets_sent*packet_bsize+1:(packets_sent+1)*packet_bsize) == zeros(1,packet_bsize);
                        received_signal_no_crc(packets_sent*packet_bsize+1:(packets_sent+1)*packet_bsize) = received_packet;
                        received_signal_no_crc(end-coded_rem+1:end) = data;
                    end
                    break
                else
                    received_signal_no_crc(packets_sent*packet_bsize+1:(packets_sent+1)*packet_bsize) = received_packet;
                    received_signal_no_crc(end-coded_rem+1:end) = data;
                    failed_packet_transmissions = 1 + failed_packet_transmissions;
                end
            else
                % Get current packet
                curr_packet = coded_signal(packets_sent+1, :);

                % Transmit it with PSK mod
                modulated_packet = pskmod(curr_packet, M);
                received_packet = awgn(modulated_packet, SNR);
                demodulated_packet = pskdemod(received_packet, M);

                % Check packet integrity with CRC
                data = demodulated_packet(1:n);
                brem = demodulated_packet(n+1:end);

                if (brem == binary_rem(data, divisor))
                    fprintf("\rCRC matches for packet %d of %d", packets_sent+1, total_packets);
                    received_mess(n*packets_sent+1:n*(packets_sent+1)) = data;
                    received_signal(packets_sent*packet_bsize+1:(packets_sent+1)*packet_bsize) = received_packet;
                    if isequal(received_signal_no_crc(packets_sent*packet_bsize+1:(packets_sent+1)*packet_bsize),zeros(1,packet_bsize));
                        received_signal_no_crc(packets_sent*packet_bsize+1:(packets_sent+1)*packet_bsize) = received_packet;
                        received_mess_no_crc(n*packets_sent+1:n*(packets_sent+1)) = data;
                    end
                    packets_sent = packets_sent+1;
                else
                    received_signal_no_crc(packets_sent*packet_bsize+1:(packets_sent+1)*packet_bsize) = received_packet;
                    received_mess_no_crc(n*packets_sent+1:n*(packets_sent+1)) = data;
                    failed_packet_transmissions = 1 + failed_packet_transmissions;
                end
            end
        end
        fprintf("\rAll packets transmitted. Had to retry packet transmission %d times\n", failed_packet_transmissions);


        % Now we have an array received_mess which should contain the
        % same bits as our original message.
        % Let's write this array to the outfile
        for i = 1:8:numel(received_mess)
            fprintf("\rCopying decoded byte %d of %d...", (i-1)/8+1, numel(received_mess)/8);
            uint8_value = uint8(bi2de(received_mess(i:i+7), 'left-msb'));
            fwrite(outfile, uint8_value, 'uint8');
        end
        fclose(outfile);
        fprintf("\rAll bytes copied to outfile.                      \n");


        % Show efficiency of the system:
        fprintf("--------\n");
        fprintf("ANALYSIS\n");
        fprintf("--------\n");
        % BER
        [number,ratio] = biterr(received_mess, message);
        [number_no_crc,ratio_no_crc] = biterr(received_mess_no_crc, message);
        fprintf("BER without CRC: %d errors in decoded message (%f per million bits)\n", number_no_crc, ratio_no_crc*1000000);
        fprintf("BER with CRC: %d errors in decoded message (%f per million bits)\n", number, ratio*1000000);
        fprintf("Our CRC implementation made the BER %f times better\n", number_no_crc/number);
        fprintf("While only using %f more bandwith\n", (total_packets*packet_bsize)/message_bsize);

        % Eye pattern
        if numel(received_signal) > 3000
            received_signal = received_signal(1:3000);
            received_signal_no_crc = received_signal_no_crc(1:3000);
        end
        eye_no_crc = eyediagram(received_signal_no_crc, 2);
        axes_handles = findobj(eye_no_crc, 'Type', 'axes');
        subplot_title1 = 'Eye Pattern for In-Phase Signal without CRC';
        subplot_title2 = 'Eye Pattern for Quadrature Signal without CRC';
        axes(axes_handles(1));
        title(subplot_title1);
        axes(axes_handles(2));
        title(subplot_title2);

        eye_crc = eyediagram(received_signal, 2);
        axes_handles = findobj(eye_crc, 'Type', 'axes');
        subplot_title1 = 'Eye Pattern for In-Phase Signal with CRC';
        subplot_title2 = 'Eye Pattern for Quadrature Signal with CRC';
        axes(axes_handles(1));
        title(subplot_title1);
        axes(axes_handles(2));
        title(subplot_title2);
        
        

        % Constellation diagram
        figure()
        scatter(real(received_signal_no_crc), imag(received_signal_no_crc), "filled");
        title('Constellation Diagram without CRC');
        xlabel('In-Phase (I)');
        ylabel('Quadrature (Q)');

        grid on;
        figure()
        scatter(real(received_signal), imag(received_signal), "filled");
        title('Constellation Diagram with CRC');
        xlabel('In-Phase (I)');
        ylabel('Quadrature (Q)');
        grid on;

    catch err
        if strcmp(err.identifier, "MATLAB:FileIO:InvalidFid")
            error("Invalid infile");
        else
           rethrow(err);
        end
    end
end
