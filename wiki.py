#!/opt/homebrew/bin/python3

import bz2
import xml.etree.ElementTree as ET
import os
import re
import subprocess
import time
import traceback
import random
import datetime


total_time = time.time()

index_path = os.path.expanduser('~') + "/nomadwiki/enwiki-latest-pages-articles-multistream-index.txt"
bz2_path = os.path.expanduser('~') + "/nomadwiki/enwiki-latest-pages-articles-multistream.xml.bz2"
mu_path = os.path.expanduser('~') + "/nomadwiki/mu.lua"
last_update_date = open(os.path.expanduser('~') + "/nomadwiki/last_update", "r").readlines()

view = os.environ.get('var_view')
page = os.environ.get('var_page')
reset = os.environ.get('var_reset')
search_text = os.environ.get('field_search')

if view == None:
  view = "index"
if search_text == None or reset != None:
  search_text = ""

template = """`r {time}s|{last_update}
`a
# banner
`c
`=
 _______                             .___  __      __.__ __   .__ 
 \\      \\   ____   _____ _____     __| _/ /  \\    /  \\__|  | _|__|
 /   |   \\ /  _ \\ /     \\\\__  \\   / __ |  \\   \\/\\/   /  |  |/ /  |
/    |    (  <_> )  Y Y  \\/ __ \\_/ /_/ |   \\        /|  |    <|  |
\\____|__  /\\____/|__|_|  (____  /\\____ |    \\__/\\  / |__|__|_ \\__|
        \\/             \\/     \\/      \\/         \\/          \\/   

`=
`a
# navigation options
`F07a`_`[Home`:/page/wiki.mu`reset|view=home]`_`f `B444`<32|search`{search_text}>`b `F07a`_`[Search`:/page/wiki.mu`search|view=search]`_`f
`Bddd`F222

`c`!{title}`!

`a
`b`f

{content}
"""

race_content_template = """
    `cWiki Race
    Your goal is to get from page {start_page} to page {end_page} in the least number of clicks. Good luck!
    {start_link}
    `a
"""

def get_wikitext(dump_filename, offset, page_id=None, title=None, namespace_id=None, verbose=True, block_size=256*1024):
    unzipper = bz2.BZ2Decompressor()

    uncompressed_data = b""
    with open(dump_filename, "rb") as infile:
        infile.seek(int(offset))

        while True:
            compressed_data = infile.read(block_size)
            try:
                uncompressed_data += unzipper.decompress(compressed_data)
            except EOFError:
                break
            if compressed_data == '':
              break
        if unzipper.needs_input:
          raise Exception("Failed to read a complete stream")

    uncompressed_text = uncompressed_data.decode("utf-8")
    xml_data = "<root>" + uncompressed_text + "</root>"
    root = ET.fromstring(xml_data)
    for page in root.findall("page"):
        if title is not None:
            if title != page.find("title").text:
                continue
        if namespace_id is not None:
            if namespace_id != int(page.find("ns").text):
                continue
        if page_id is not None:
            if page_id != int(page.find("id").text):
                continue
        revision = page.find("revision")
        wikitext = revision.find("text")
        return wikitext.text

    return None

def get_wikipage(index_line):
    index_pieces = index_line.split(":")
    if len(index_pieces) == 1:
        page_index = search_index(index_line, True)
        index_pieces = page_index.split(":")

    wikitext = get_wikitext(bz2_path, int(index_pieces[0]), page_id=int(index_pieces[1]))
    if (wikitext.startswith('#REDIRECT')):
    #    print("`=\n" + wikitext + "\n`=")
       redirect_page = wikitext.strip().split("\n")[0].replace("#REDIRECT", "").replace("[[", "").replace("]]", "").strip()
       redirect_index = search_index(redirect_page, True)
       if redirect_index != None:
        return get_wikipage(redirect_index)
       else:
          return None

    if not wikitext:
        print("Failed to retrieve wikitext.")
        return None
    
    wikitext = wikitext.replace("|class=\"wikitable\"\n|+", "<temp>")
    wikitext = wikitext.replace("|+\n", "|-\n")
    wikitext = wikitext.replace("<temp>", "|class=\"wikitable\"\n|+")
    wikitext = wikitext.replace("\";", "\"")
    # print(wikitext)

    return wikitext

def format_micron(wikitext):
    # Define the command to run Pandoc with the Lua filter
    pandoc_command = [
        'pandoc',
        '--lua-filter=' + mu_path,
        '-f', 'mediawiki',
        '-t', 'plain'
    ]

    try:
        # Use subprocess to run the command and capture the output
        process = subprocess.Popen(
            pandoc_command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        # Pass wikitext to Pandoc and get the output
        output, error = process.communicate(input=wikitext)

        if process.returncode != 0:
            return f"An exception occurred while converting the file: {error}\n\n\n" + "`=\n" + wikitext + "\n`="
        
        output = output.replace("-   ", "* ")
        output = output.replace("\\`", "\\\\`")
        output = output.replace("\n\n, ", ", ")
        output = output.replace(",\n\n", ", ")

        # uncomment the back half of the following line to see the raw wikimedia output
        return output #+ "`=\n" + wikitext + "\n`=" 

    except Exception as e:
        print(f"Exception occurred: {e}")
        return None

def search_index(search_text, exact_match=False):
    # TODO: sanitize user input
    formatted_search_text = search_text.split("#", 1)[0]
    formatted_search_text = formatted_search_text.replace("_", " ")

    if exact_match:
        pattern = f'[0-9]+:{re.escape(formatted_search_text)}$'
        pattern = pattern.replace("\ ", " ")
        command = ['rg', pattern, index_path]
    else:
        pattern = formatted_search_text
        command = ['rg', "--ignore-case", pattern, index_path]

    # Run the command and capture output
    try:
        result = subprocess.run(command, check=True, stdout=subprocess.PIPE, text=True)
    except Exception as e:
        if exact_match:
            # no results found, try again without exact matching
            search_results = search_index(formatted_search_text, exact_match=False)
            matches = [s for s in search_results.split("\n") if s.lower().endswith(":" + formatted_search_text.lower()) and len(s.split(":")) == 3]
            if matches:
                return matches[0]
            else:
                print("no search results")
                return None
        else:
            return None

    # Return the output
    if exact_match:
        return result.stdout.strip().split("\n")[0]
    return result.stdout

def main():
    try:
        if view == "search" and search_text != None:
            search_results = search_index(search_text)
            if search_results == None:
                print(template.format(title=f"No results for {search_text}", content="", search_text=search_text, time=round(time.time() - total_time, 4), last_update=last_update_date[0]))
                return
            else:
                results = search_results.split("\n")
            
            formatted_results = []
            for result in results[:30]:
                page_details = result.split(":")
                formatted_results.append(f"* `F00a`_`[{page_details[-1]}`:/page/wiki.mu`page={page_details[-1]}]`_`f\n")
            print(template.format(title=f"Results: {search_text}", content="\n".join(formatted_results), search_text=search_text, time=round(time.time() - total_time, 4), last_update=last_update_date[0]))
        elif view == "race":
            today = datetime.date.today().isoformat()
            seed = int(today.replace("-", ""))
            rng = random.Random(seed)
            command = ['wc', "-l", index_path]
            lineCountResult = subprocess.run(command, check=True, stdout=subprocess.PIPE, text=True)
            lineCount = int(lineCountResult.stdout.strip().split(" ")[0])
            startPageIndex = rng.randint(1, lineCount)
            endPageIndex = rng.randint(1, lineCount)

            start_page_details_command = ['sed', f"{startPageIndex}q;d", index_path]
            end_page_details_command = ['sed', f"{endPageIndex}q;d", index_path]

            race_content = race_content_template.format(start_page=startPageIndex, end_page=endPageIndex, start_link=f"`F07a`_`[Start - {startPageIndex}`:/page/wiki.mu`page={startPageIndex}]`_`f\n")

            print(template.format(title="Wiki Race", content=race_content, search_text=search_text, time=round(time.time() - total_time, 4), last_update=last_update_date[0]))
        elif page != None:
            index_details = search_index(page, True)
            wikitext = get_wikipage(index_details)
            output = format_micron(wikitext, )

            print(template.format(title=index_details.split(":")[-1], content=output, search_text=search_text, time=round(time.time() - total_time, 4), last_update=last_update_date[0]))
        else:
            print(template.format(title="Welcome to Nomad Wiki!", content="`cAn offline text-only copy of wikipedia built for NomadNet", search_text=search_text, time=round(time.time() - total_time, 4), last_update=last_update_date[0]))
    except Exception as e:
        # Print the error details
        print(traceback.format_exc())
        print(f"An error occurred: {e}")

main()
