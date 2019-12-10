bit = require 'bit'

function CalculateCrc(buffer)
    local sum = 0
    for i = 2, string.len( buffer ) - 1 do
        local byte = string.byte(buffer, i)
        sum = sum + byte
    end
    return bit.bnot(sum - 0x01)
end

function CheckCrcMatch(a, b)
    return string.sub(string.format("%02X", a), -2) == string.sub(string.format("%02X", b), -2)
end

-- function GetByteFromBuffer(buffer, index, useAlt)
--     local normalBytesMap = { [0]=1; [1]=2; [2]=3; [3]=4; [4]=5; [5]=6; [6]=7; [7]=8; [8]=9 }
--     local alternativeBytesMap = { [0]=5; [1]=6; [2]=7; [3]=8; [4]=9; [5]=1; [6]=2; [7]=3; [8]=4 }
--     if useAlt then
--         return string.byte(buffer, alternativeBytesMap[index])
--     else
--         return string.byte(buffer, normalBytesMap[index])
--     end
-- end

local buffer = string.char(0xFF,0x86,0x04,0x32,0x43,0x00,0x00,0x00,0x01)

local received_crc = string.byte(buffer, 9)

local calculated_crc = CalculateCrc(buffer)

print(received_crc)
print(calculated_crc)

-- local buffer = string.char(0xFF, 0x86, 0x01, 0xAE, 0x44, 0x00, 0x00, 0x00, 0x87)

-- if checkMatch(calculated_crc, received_crc) then
--     print("checksum match!")
-- else
--     print("checksum mismatch:(")
-- end

-- local buffer = string.char(0x00, 0x00, 0x00, 0x9B, 0xFF, 0x86, 0x01, 0x9A, 0x44)
-- local normalStartByte = GetByteFromBuffer(buffer, 0, false)
-- local normalEchoCmd = GetByteFromBuffer(buffer, 1, false)
-- local altStartByte = GetByteFromBuffer(buffer, 0, true)
-- local altEchoCmd = GetByteFromBuffer(buffer, 1, true)

-- print('normalStartByte', normalStartByte)
-- print('normalEchoCmd', normalEchoCmd)
-- print('altStartByte', altStartByte)
-- print('altEchoCmd', altEchoCmd)

-- local useAlt = nil

-- if altStartByte == 0xFF and altEchoCmd == 0x86 then
--     useAlt = true
-- elseif normalStartByte == 0xFF and normalEchoCmd == 0x86 then
--     useAlt = false
-- end

-- print('useAlt', useAlt)

-- local co2HighByte = GetByteFromBuffer(buffer, 2, useAlt)
-- local co2LowByte = GetByteFromBuffer(buffer, 3, useAlt)
-- local temperatureRaw = GetByteFromBuffer(buffer, 4, useAlt)
-- local receivedCrc = GetByteFromBuffer(buffer, 8, useAlt)

-- print('co2HighByte', co2HighByte)
-- print('co2LowByte', co2LowByte)
-- print('temperatureRaw', temperatureRaw)
-- print('receivedCrc', receivedCrc)

-- if string.sub(string.format("%X", calculated_crc), -2) == string.format("%X", received_crc) then

-- oct2bin = {
--     ['0'] = '000',
--     ['1'] = '001',
--     ['2'] = '010',
--     ['3'] = '011',
--     ['4'] = '100',
--     ['5'] = '101',
--     ['6'] = '110',
--     ['7'] = '111'
-- }
-- function getOct2bin(a) return oct2bin[a] end
-- function convertBin(n)
--     local s = string.format('%o', n)
--     s = s:gsub('.', getOct2bin)
--     return s
-- end

-- print(i, '=', byte)
-- return sum
-- return (sum) + 0x01
-- return 0xFF - (sum - 0x01)
-- return bit.bnot(sum)
-- return bit.band(sum, 0xFF)
-- return bit.bxor(sum, 0xFF)
-- local buffer = string.char(0xFF, 0x86, 0x05, 0x41, 0x44, 0x00, 0x00, 0x00, 0xF0)
-- local buffer = string.char(0xFF, 0x86, 0x05, 0x4E, 0x44, 0x00, 0x00, 0x00, 0xE3)
-- local buffer = string.char(0xFF, 0x86, 0x02, 0x60, 0x47, 0x00, 0x00, 0x00, 0xD1)

-- request
-- local buffer = string.char(0xFF, 0x01, 0x86, 0x00, 0x00, 0x00, 0x00, 0x00, 0x79)

-- from js
-- local buffer = string.char(0xFF, 0x86, 0x01, 0x9A, 0x44, 0x00, 0x00, 0x00, 0x9B)


-- print('received_crc', received_crc, convertBin(received_crc))
-- print('calculated_crc', calculated_crc, convertBin(calculated_crc))

-- print('calculated_crc', 376, convertBin(376))
-- print('calculated_crc', 377, convertBin(377))
-- print('calculated_crc', 377, convertBin(bit.bnot(377) - 1))

--                                                          010000110
-- 001111111111111111111111111111111111111111111111111111111101111001

-- received_crc	                                                             010011011
-- calculated_crc	001111111111111111111111111111111111111111111111111111111010011011

-- received_crc	                                                             010011011
-- calculated_crc	001111111111111111111111111111111111111111111111111111111110011011

-- print(--[[ convertBin ]](0x86))
-- print(--[[ convertBin ]]((0xFF - 0x86) + 0x01))

-- print(convertBin(bit.bxor(0x86, 0xFF)))
-- print(convertBin(bit.bnot(0x86)))

-- print(crc)
-- print(string.format("0x%02X", crc))


-- 010000111 received

-- 101111001 sum
-- 101111000 sum - 1
-- 010000111 inverted(sum - 1)
