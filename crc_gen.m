function [crc_bits] = crc_check(data,generator)
    generator_bsize = numel(generator);
    crc_bsize = generator_bsize - 1;
    while true
        if numel(data) == crc_bsize
            break;
        end
        if data(1) == 0
            data = data(2:end);
        else
            for i = 1:generator_bsize
                data(i) = int8(xor(data(i), generator(i)));
            end
        end
    end
    crc_bits = data;
end
