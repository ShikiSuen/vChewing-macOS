// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#ifndef ASSOCIATEDPHRASES_H
#define ASSOCIATEDPHRASES_H

#include <iostream>
#include <map>
#include <string>
#include <vector>

namespace vChewing
{

class AssociatedPhrases
{
  public:
    AssociatedPhrases();
    ~AssociatedPhrases();

    const bool isLoaded();
    bool open(const char *path);
    void close();
    const std::vector<std::string> valuesForKey(const std::string &key);
    const bool hasValuesForKey(const std::string &key);

  protected:
    struct Row
    {
        Row(std::string_view &k, std::string_view &v) : key(k), value(v)
        {
        }
        std::string_view key;
        std::string_view value;
    };

    std::map<std::string_view, std::vector<Row>> keyRowMap;

    int fd;
    void *data;
    size_t length;
};

} // namespace vChewing

#endif /* AssociatedPhrases_hpp */
