on adding folder items to thisFolder after receiving addedItems
    set compressorScript to POSIX path of (path to home folder) & "Library/Application Support/CleanShot Compressor/compress-new-videos.sh"

    repeat with addedItem in addedItems
        set itemPath to POSIX path of addedItem
        try
            with timeout of 86400 seconds
                do shell script quoted form of compressorScript & " --file " & quoted form of itemPath & " >/dev/null 2>&1"
            end timeout
        end try
    end repeat
end adding folder items to
