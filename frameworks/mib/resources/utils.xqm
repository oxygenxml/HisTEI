xquery version "3.0";

(:~
 : A set of generic XML helper functions for use in XQuery scripts in the HisTEI framework
 :)
module namespace utils="http://histei.info/xquery/utils";

import module namespace functx="http://www.functx.com" at "functx.xql";

declare namespace decoder="java:java.net.URLDecoder";
declare namespace map="http://www.w3.org/2005/xpath-functions/map";

(: Errors :)
(: Raised by utils:update-content-ordered() if no fieldNames are provided either as xs:string+ or map(xs:string, xs:string+) :)
declare %private variable $utils:NO_FIELD_NAMES_ERROR := QName("http://histei.info/xquery/utils/error", "NoFieldNamesError");


(: Generic functions for processing URIs :)

(:~
 : Appends a filename to a base path using the slash separator (/)
 : 
 : @param $dir URI to a directory.
 : @param $file File name to be appended to the directory.
 : @return Full URI to the file.
:)
declare function utils:resolve-uri($dir as xs:string?, $file as xs:string?) as xs:string? {
    if (empty($dir) or $dir eq "") then
        ()
    else
        let $dir := 
            if (ends-with($dir, "/")) then
                $dir
            else
                concat($dir, "/")
        return
            concat($dir, $file)
};

declare function utils:resolve-uri($dir as xs:string?) as xs:string? {
    utils:resolve-uri($dir, ())
};

(:~
 : Gets the document URI and then returns the filename portion of the path for each input document-node()
 : 
 : @param $docs Set of document nodes (e.g. from a call to collection())
 : @return Set of filenames, one for each document-node in $docs
:)
declare function utils:filenames($docs as document-node()*) as xs:string* {
    for $doc in $docs
    return
        decoder:decode(functx:substring-after-last(string(document-uri($doc)), "/"), "UTF-8")
};

(:~
 : Gets the document URI and then returns the base portion (without the extension) of the filename for each input document-node()
 : 
 : @param $docs Set of document nodes (e.g. from a call to collection())
 : @return Set of file basenames (without extension), one for each document-node in $docs
:)
declare function utils:file-basenames($docs as document-node()*) as xs:string* {
    let $filenames := utils:filenames($docs)
    for $filename in $filenames
    return
        functx:substring-before-last($filename, ".")
};

(: Generic functions for processing XML :)

(:~
 : Returns set of preceding-siblings by subsequencing from the parent node (instead of using the resource-intensive preceding-sibling XPath axis)
 : - This is a replacement for any calls to the preceding-sibling axis
 : 
 : @param $element Element whose preceding-siblings are to be returned.
 : @return Set of preceding-sibling nodes relative to the input element.
:)
declare function utils:preceding-sibling($element as element()?) as node()* {
    utils:sibling($element, true())
};

(:~
 : Returns set of following-siblings by subsequencing from the parent node (instead of using the resource-intensive following-sibling XPath axis)
 : - This is a replacement for any calls to the following-sibling axis
 : 
 : @param $element Element whose following-siblings are to be returned.
 : @return Set of following-sibling nodes relative to the input element.
:)
declare function utils:following-sibling($element as element()?) as node()* {
    utils:sibling($element, false())
};

(:~
 : Returns set of siblings by subsequencing from the parent node (instead of using the resource-intensive sibling XPath axis)
 : - This is a replacement for any calls to the sibling axes
 : 
 : @param $element Element whose siblings are to be returned.
 : @param $previous Direction to search for siblings. If true, preceding-siblings are selected, else following-siblings are selected.
 : @return Set of sibling nodes relative to the input element.
:)
declare function utils:sibling($element as element()?, $previous as xs:boolean) as node()* {
    let $parent := $element/parent::*[1]
    return
        if ($previous) then 
            subsequence($parent/node(), 1, functx:index-of-node($parent/node(), $element) - 1)
        else 
            subsequence($parent/node(), functx:index-of-node($parent/node(), $element) + 1)
};

(:~
 : Returns true if the given attribute exists and does not contain an empty string
 : 
 : @param $string String to be checked for whitespace
 : @param $type Can be "anywhere", "starts", "ends", "all". If none of those options are given, the default is "anywhere".
 : @return True if whitespace is present for the given $type
:)
declare function utils:attr-exists($attribute as attribute()?) as xs:boolean {
    exists($attribute) and $attribute ne ""
};

(:~
 : Returns true if the given string contains whitespace specified by the type of check
 :  - Field names that are not valid QNames are prefixed with f_ (this is always the case if the file has no headers)
 : 
 : @param $string String to be checked for whitespace
 : @param $type Can be "anywhere", "starts", "ends", "all". If none of those options are given, the default is "anywhere".
 : @return True if whitespace is present for the given $type
:)
declare function utils:contains-ws($string as xs:string?, $type as xs:string?) as xs:boolean {
    let $regex :=
        switch ($type)
        case "starts" return "^\s"
        case "ends" return "\s$"
        case "all" return "^\s+$"
        default return "\s"
    return
        matches($string, $regex)
};

declare function utils:contains-ws($string as xs:string?) as xs:boolean {
    utils:contains-ws($string, ())
};

(:~
 : Checks if a text() node is an empty Oxygen comment 
 :  (i.e. all whitesapce surrounded by oxy_comment_start and oxy_comment_end processing instructions) 
 : 
 : @param $textNode text() node to be checked
 : @return True if the text() node is all whitespace and surrounded by Oxygen comment processing instructions
:)
declare function utils:is-empty-oxy-comment($textNode as node()?) as xs:boolean {
    (
        exists($textNode) 
        and $textNode instance of text()
        and $textNode/preceding-sibling::node()[1] instance of processing-instruction(oxy_comment_start)
        and $textNode/following-sibling::node()[1] instance of processing-instruction(oxy_comment_end)
        and normalize-space($textNode) eq ""
    )
};

(:~
 : Get all text() nodes below the given element that contain text (i.e. not just whitespace) 
 : 
 : @param $element element() node to retrieve text() nodes from
 : @return Set of text() nodes that contain text 
:)
declare function utils:non-empty-text-nodes($element as element()) as text()* {
    $element//text()[normalize-space() ne ""]
};

(:~
 : Generate a new element with the given name within the given namespace
 : - If no namespace is given, an element in the 'empty' namespace is returned
 : 
 : @param $name name for the new element, including the optional prefix
 : @param $content content to go inside the new element
 : @param $namespace XML namespace for the new element, no namespace results in an element in the 'empty' namespace
 : @return New element() node with the given name within the given namespace containing the supplied content
:)
declare function utils:element-NS($name as xs:string, $content, $namespace as xs:string?) as element() {
    element { QName($namespace, $name) } { $content }
};

declare function utils:element-NS($name as xs:string, $content) as element() {
    utils:element-NS($name, $content, ())
};

(:~
 : Generate a new attribute with the given name within the given namespace
 : - If no namespace is given, an attribute in the 'empty' namespace is returned
 : 
 : @param $name name for the new attribute, including the optional prefix
 : @param $value the value for the new attribute
 : @param $namespace XML namespace for the new attribute, no namespace results in an attribute in the 'empty' namespace
 : @return New attribute() node with the given name within the given namespace containing the supplied value
:)
declare function utils:attribute-NS($name as xs:string, $value as xs:anyAtomicType?, $namespace as xs:string?) as attribute()? {
    if (empty($value) or string($value) eq "") then
        ()
    else
        attribute { QName($namespace, $name) } { $value }
};

declare function utils:attribute-NS($name as xs:string, $value as xs:anyAtomicType?) as attribute()? {
    utils:attribute-NS($name, $value, ())
};

(:~
 : Transform an element by replacing its contents
 : - If new attributes are provided, existing attributes are overwritten, otherwise they are copied 
 : 
 : @param $element element() node to have its content replaced
 : @param $newContent Set of item() values that will replace existing content
 : @param $newAttributes Set of attribute() nodes to overwrite the element() node's existing attributes
 : @return New element() node containing $newContent, with the same node-name() as the original element() node
:)
declare function utils:replace-content($element as element(), $newContent, 
                                            $newAttributes as attribute()*) as element() {
    element { node-name($element) } {
        if (exists($newAttributes)) then $newAttributes else $element/@*,
        $newContent
    }
};

declare function utils:replace-content($element as element(), $newContent) as element() {
    utils:replace-content($element, $newContent, ())
};

(:~
 : Merge new attributes with those on an existing element
 : 
 : @param $element element() node to update the attributes on
 : @param $newAttributes Set of attribute() nodes to merge with the element() node's existing attributes
 : @return New element() Node containing $newAttributes merged with existing attributes
:)
declare function utils:update-attributes($element as element(), $newAttributes as attribute()*) as element() {
    let $newAttrNames := for $attr in $newAttributes return local-name($attr)
    return
        element { node-name($element) } {
            $element/@* except $element/@*[local-name() = $newAttrNames], 
            $newAttributes
        }
};

(:~
 : Update the content of an element() node that requires the elements below it to be in a specific order
 : - Also returns original nodes that are not affected by the update (e.g. comments, processing instructions)
 : - Items being added take precedence over older nodes and therefore come first in the output
 : 
 : @param $element element() node with ordered sub-elements to be updated
 : @param $fieldNames Ordered set of all possible element names that could appear beneath the main element() node.
 :  Either a set of at least one string, i.e. xs:string+ or a map using the element() node's local-name as the key 
 :  with the value being the ordered set of element names, i.e. map(xs:string, xs:string+) 
 : @param $newElements Set of new element() nodes to update the existing content with
 : @return New element() node containing updated content in the order of $fieldNames, 
 :  with $newElements replacing the original element where present
 : @error If $fieldNames is neither of type xs:string+ nor map(xs:string, xs:string+), a NoFieldNamesError is thrown
:)
declare function utils:update-content-ordered($element as element(), $fieldNames as item()+, 
                                                            $newElements as element()*) as element() {
    let $nodes := $element/node()
    let $fieldNames := 
        if ($fieldNames instance of xs:string+) then
            $fieldNames
        else if ($fieldNames instance of map(xs:string, xs:string+)) then
            $fieldNames(local-name($element))
        else
            error($utils:NO_FIELD_NAMES_ERROR, concat("No valid fieldNames were provided! ",
                "The $fieldNames variable must be either xs:string+ or map(xs:string, xs:string+)."))
    
    let $fieldsMap := map:new(
        for $fieldName in $fieldNames
        return
            map:entry($fieldName, 
                for $node at $pos in $nodes
                return
                    if ($node instance of element() and local-name($node) eq $fieldName) then
                        $pos
                    else
                        ()
            )
    )
    let $startFunc := function($pos as xs:integer) as xs:integer {
        if ($pos eq 1) then 
            1 
        else 
            let $prevLocs := for $n in (1 to $pos - 1) return $fieldsMap($fieldNames[$n])[last()]
            return
                if (exists($prevLocs)) then $prevLocs[last()] + 1 else 1
    }
    let $newNodes := 
        for $fieldName at $pos in $fieldNames
        let $newElement := $newElements[local-name() eq $fieldName]
        
        let $locs := $fieldsMap($fieldName)
        let $oldElement := 
            if (empty($locs)) then
                ()
            else if (count($locs) eq 1) then
                $nodes[$locs[1]]
            else
                subsequence($nodes, $locs[1], ($locs[last()] - $locs[1]) + 1)
        
        let $updatedElement := 
            if (exists($newElement)) then 
            (
                $newElement,
                $oldElement except $oldElement[local-name() eq $fieldName]
            )
            else 
                $oldElement
        
        let $prevNodes := 
            if (empty($locs)) then
                ()
            else
                let $start := $startFunc($pos)
                return
                    subsequence($nodes, $start, $locs[1] - $start)
        return
            ( $prevNodes, $updatedElement )
    return
        element { node-name($element) } {
            $element/@*,
            $newNodes,
            subsequence($nodes, $startFunc(count($fieldNames) + 1))
        }
};

(: Functions for importing/converting text files into/to XML :)

(:~
 : Parse a set of tab-delimited lines and convert them to a set of XML row elements.
 : Elements within each row represent fields in the original tab-delimited row
 :  - Field names are either header names taken from the first row (when $hasHeaders is true) or 
 :      an f_ prefix followed by the ordinal position of each field
 :  - When $hasHeaders is true, field names that are not valid QNames are also prefixed with f_
 : 
 : @param $lines Set of strings taken from a tab-delimited text file
 : @param $hasHeaders Whether the first line contains the names of the fields. Default is true.
 : @return Set of row elements containing fields named using headers in the first line or ordinal names
:)
declare function utils:parse-tab-lines($lines as xs:string*, $hasHeaders as xs:boolean?) as element(row)* {
    let $fieldPrefix := "f_"
    let $hasHeaders := if (empty($hasHeaders)) then true() else $hasHeaders
    
    let $fieldNames := 
        for $field at $pos in tokenize($lines[1], "\t")
        return
            if ($hasHeaders) then
                let $field := normalize-space($field)
                return
                    if ($field castable as xs:QName) then 
                        $field 
                    else 
                        concat($fieldPrefix, $field)
            else
                concat($fieldPrefix, $pos)
           
    let $body := if ($hasHeaders) then subsequence($lines, 2) else $lines
    
    for $line in $body
    return
        element row {
            for $field at $pos in tokenize($line, "\t")
            let $fieldName := $fieldNames[$pos]
            let $fieldName := if (empty($fieldName) or $fieldName eq "") then concat($fieldPrefix, $pos) else $fieldName
            return
                element { $fieldName } { normalize-space($field) }
        }
};

declare function utils:parse-tab-lines($lines as xs:string*) as element(row)* {
    utils:parse-tab-lines($lines, ())
};








