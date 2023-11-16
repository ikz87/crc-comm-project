function [brem] = binary_rem(dividend, divisor)
    % Convert to decimal
    decimal_dividend = bi2de(dividend, 'left-msb');
    decimal_divisor = bi2de(divisor, 'left-msb');

    % Get remainder
    decimal_remainder = mod(decimal_dividend, decimal_divisor);

    % Convert the remainder back to binary representation
    brem = de2bi(decimal_remainder, numel(divisor), 'left-msb');
end

