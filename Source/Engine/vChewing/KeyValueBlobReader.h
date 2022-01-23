/* 
 *  KeyValueBlobReader.h
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

#ifndef SOURCE_ENGINE_KEYVALUEBLOBREADER_H_
#define SOURCE_ENGINE_KEYVALUEBLOBREADER_H_

#include <cstddef>
#include <functional>
#include <iostream>
#include <string_view>

// A reader for text-based, blank-separated key-value pairs in a binary blob.
//
// This reader is suitable for reading language model files that entirely
// consist of key-value pairs. Leading or trailing spaces are ignored.
// Lines that start with "#" are treated as comments. Values cannot contain
// spaces. Any space after the value string is parsed is ignored. This implies
// that after a blank, anything that comes after the value can be used as
// comment. Both ' ' and  '\t' are treated as blank characters, and the parser
// is agnostic to how lines are ended, and so LF, CR LF, and CR are all valid
// line endings.
//
// std::string_view is used to allow returning results efficiently. As a result,
// the blob is a const char* and will never be mutated. This implies, for
// example, read-only mmap can be used to parse large files.
namespace vChewing {

class KeyValueBlobReader {
public:
    enum class State : int {
        // There are no more key-value pairs in this blob.
        END = 0,
        // The reader has produced a new key-value pair.
        HAS_PAIR = 1,
        // An error is encountered and the parsing stopped.
        ERROR = -1,
        // Internal-only state: the parser can continue parsing.
        CAN_CONTINUE = 2
    };

    struct KeyValue {
        constexpr KeyValue()
            : key("")
            , value("")
        {
        }
        constexpr KeyValue(std::string_view k, std::string_view v)
            : key(k)
            , value(v)
        {
        }

        bool operator==(const KeyValue& another) const
        {
            return key == another.key && value == another.value;
        }

        std::string_view key;
        std::string_view value;
    };

    KeyValueBlobReader(const char* blob, size_t size)
        : current_(blob)
        , end_(blob + size)
    {
    }

    // Parse the next key-value pair and return the state of the reader. If
    // `out` is passed, out will be set to the produced key-value pair if there
    // is one.
    State Next(KeyValue* out = nullptr);

private:
    State SkipUntil(const std::function<bool(char)>& f);
    State SkipUntilNot(const std::function<bool(char)>& f);

    const char* current_;
    const char* end_;
    State state_ = State::CAN_CONTINUE;
};

std::ostream& operator<<(std::ostream&, const KeyValueBlobReader::KeyValue&);

} // namespace vChewing

#endif // SOURCE_ENGINE_KEYVALUEBLOBREADER_H_
