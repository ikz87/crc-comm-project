function []=main(infile_path, outfile_path, divisor)
    try
        infile  = fopen(infile_path, 'r');
        data = fread(infile, [1, Inf], 'uint8');
        fclose(infile);
        bits = uint8(rem(floor((1 ./ [128, 64, 32, 16, 8, 4, 2, 1].') * data), 2));
        bits = bits(:);

        % We'll add a CRC after every packet
        % of n bits
        n = 8

        % Initialize an array with the size of
        % our (to be) coded message
        while true
            packet = bits(1:n)
            bits = bits(n+1:end)

            if numel(bits) < n 
                % TODO
                break
            end
        end

    catch err
        if strcmp(err.message, 'Not enough input arguments.')
            fprintf('Usage: main <infile> <outfile> <divisor>\n')
        else
            rethrow(err);
        end
end
