function [brem] = binary_rem(data,crc)
    crcw = length(crc)-1;
    initVal = zeros(1,crcw);
    finalXOR = zeros(1,crcw);
    am = [data,zeros(1,crcw)];
    am(1:crcw) = xor(am(1:crcw),initVal);

    % CRC calculation
    reg = [0,am(1:crcw)];
    for i=crcw+1:length(am)
        reg = [reg(2:end),am(i)];
        if reg(1)==1
            reg = xor(reg, crc);
        end
    end
    mcrc = reg(2:end);
    brem = xor(mcrc,finalXOR);

    crc_bsize = numel(crc);
    brem_bsize = numel(brem);
    if (brem_bsize < crc_bsize)
        brem = [ zeros(1,crc_bsize - brem_bsize) brem];
end

