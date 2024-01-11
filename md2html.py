import markdown
import sys

if len(sys.argv) == 3:
    print("debug arg0 ",sys.argv[0]," arg1 ",sys.argv[1]," arg2 ",sys.argv[2],"\n")
    input=sys.argv[1]
    output=sys.argv[2]
elif len(sys.argv) != 3:
    print(
            "\n***",sys.argv[0], "***\n"
            'Incorrect number of arguments, please run script as follows:'
            '\n\n'+str(sys.argv[0])+' <nothing if you want to use default values>'
            '\n\n'+str(sys.argv[0])+' <start value> <number of records to insert>'
        )
    sys.exit(0)

# Read the input MD file
with open(input, "r") as md_file:
    md_text = md_file.read()

# Convert MD to HTML
html = markdown.markdown(md_text, extensions=['markdown.extensions.tables', 'fenced_code'])

# Write the HTML output to a file
with open(output, "w") as html_file:
    html_file.write(html)

