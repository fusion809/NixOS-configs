#!/usr/bin/env python3

def get_valid_input(prompt, min_val, max_val):
    while True:
        try:
            value = int(input(prompt))
            if min_val <= value <= max_val:
                return value
            print(f"Please enter a number between {min_val} and {max_val}.")
        except ValueError:
            print("Invalid input. Please enter a number.")

def get_multiple_valid_inputs(prompt, min_val, max_val):
    while True:
        try:
            input_str = input(prompt)
            values_str = input_str.split()
            values = []
            valid = True
            
            for v_str in values_str:
                val = int(v_str)
                if min_val <= val <= max_val:
                    values.append(val)
                else:
                    print(f"Value '{val}' is out of range. Please enter numbers between {min_val} and {max_val}.")
                    valid = False
                    break
            
            if valid and values:
                return values
            elif not values:
                 print("Please enter at least one number.")

        except ValueError:
            print("Invalid input. Please enter numbers separated by spaces.")

def recommend_distro(willingness, usecases):
    print(f"\nStats: Willingness {willingness}/5, Usecases {usecases}.")
    # Initialize list of all candidates with difficulty ratings (1-5)
    distro_choices = [
        # Easy to install, comes with proprietary drivers if needed
        {"name": "elementary OS", "difficulty": 1, "description": "A Linux distribution based on Ubuntu's long-term support (LTS) releases. It has a vaguely macOS-like look."},
        {"name": "Linux Mint", "difficulty": 1, "description": "A Linux distribution based on Ubuntu's long-term support (LTS) releases. Its default look is vaguely Windows-like and its development team has, since the distribution's founding in 2006, consistently prioritized ease of use for end users over everything else."},
        {"name": "MXLinux", "difficulty": 1, "description": "A Linux distribution based on Debian. It has its own unique look that involves a taskbar on the left-hand side of the screen. It has fairly low system requirements, so is especially suited to older hardware."},
        {"name": "Nobara", "difficulty": 1, "description": "A Linux distribution based on Fedora, but unlike Fedora it has the option to install proprietary drivers built right into its installer."},
        {"name": "PCLinuxOS", "difficulty": 1, "description": "A Linux distribution based on Slackware. It has a Windows-like look."},
        {"name": "Ubuntu", "difficulty": 1, "description": "A Linux distribution based on Debian. It has a Windows-like look."},
        {"name": "Zorin OS", "difficulty": 1},

        # Easy to install, including with drivers, but with slight issues that mightn't make them perfectly beginner friendly. This could include a small development team or user base (hence less packages and help available), or less of a beginner-friendly focus of its developers
        {"name": "Debian", "difficulty": 2},
        {"name": "Pop!_OS", "difficulty": 2},
        {"name": "Solus", "difficulty": 2},

        # Easy to install, with graphical tools for system management, but does not come with proprietary drivers
        {"name": "Fedora", "difficulty": 3},
        {"name": "Mageia", "difficulty": 3},
        {"name": "openSUSE Leap", "difficulty": 3},
        {"name": "openSUSE Tumbleweed", "difficulty": 3},
        {"name": "Rhino Linux", "difficulty": 3},

        # Easy to install, but some popular packages or features require some learning to access
        {"name": "CachyOS", "difficulty": 4},
        {"name": "EndeavourOS", "difficulty": 4},
        {"name": "Garuda Linux", "difficulty": 4},
        {"name": "Manjaro", "difficulty": 4},

        # Easy to install, but some important features require some learning to access
        {"name": "Arch Linux", "difficulty": 5},

    ]
    
    # Filter based on willingness
    # We filter out distros that are significantly harder than the user's willingness
    max_difficulty = willingness 
    if willingness == 0:
        print("It is possible to make Linux easy for you to pick up, but some learning is kind of compulsory unless you know someone willing to do all the work for you.")

    # Remove distros that vary too much from the willingness
    # We iterate over a copy to safely remove from the original list
    for distro in list(distro_choices):
        if distro["difficulty"] > max_difficulty:
            distro_choices.remove(distro)

    names = sorted([d["name"] for d in distro_choices], key=str.lower)
    if not names:
        formatted_names = "None"
    elif len(names) == 1:
        formatted_names = names[0]
    else:
        formatted_names = ", ".join(names[:-1]) + " and " + names[-1] + "."
    
    print(f"Possible distro options: {formatted_names}")
    if set(usecases).issubset({0, 1, 2, 3, 4, 8, 9, 10}):
        print("Luckily, these usecases are pretty easy to satisfy on Linux, typically anyway. It is possible that some apps you are used to using will not work well on Linux, but there should be good alternatives available.")
    elif 5 in usecases:
        print("Please check ProtonDB, https://protondb.com, for information on whether your preferred games run on Linux. If they do not, you may wish to consider either dual booting with Windows or not running Linux at all.")
    elif 6 in usecases:
        print("Beware, I seldom edit images or graphics and never edit videos, so my knowledge is all second-hand. If you primarily use Adobe products, beware that they usually do not run well on Linux. In theory, there are workarounds (e.g. virtualization or using Linux-compatible alternatives such as DaVinci Resolve for video editing), but most Adobe users that insist on using Adobe products find they need to dual boot with Windows or macOS.")
    elif 7 in usecases:
        print("Beware, I am not a mechanical engineer, so all my knowledge on this topic is second hand. AutoCAD does not run on Linux. I have heard that BricsCAD is a good Linux-compatible alternative, although it, too, is a paid product (apparently cheaper than AutoCAD,though). There are free Linux-compatible alternatives, too, like FreeCAD, but I have heard that they are lacking in some ways.")

    if 0 in usecases:
        print("Brave, Mozilla Firefox, Google Chrome, Opera, Vivaldi and many other web browsers run natively on Linux. The main exceptions that come to mind are Safari and Microsoft Edge. Most Linux distributions come with Firefox pre-installed. As for email clients, you can use your web browser as well as some dedicated email clients such as Mozilla Thunerbird to access your email on Linux.")
    elif 1 in usecases:
        print("Most Linux distributions come with LibreOffice pre-installed, which should be sufficient for most office work. That being said, LibreOffice is not very compatible with Microsoft 365 file formats like docx for Word documents. So you may notice that some formatting is lost when you open documents written in one in the other. Further, LibreOffice does have some keyboard shortcut and layout differences to Microsoft 365, which can take some getting used to.")
    elif 2 in usecases:
        print("OnlyOffice is a free office suite you can install on Linux. It is the most Microsoft 365-compatible office suite that runs natively on Linux. Although, if you need anything other than a document editor, slideshow editor and spreadsheet editor, you will probably find OnlyOffice insufficient and may have to use LibreOffice instead. An alternative route is that you can run Microsoft 365 itself via virtualization with WinBoat, for instance. But this requires a lot of spare CPU, disk space and RAM. I'd recommend at least 2 3GHz CPU cores, 40GB disk space and 8GB RAM spare for running WinBoat.")
    elif 3 in usecases:
        print("It is fairly easy to install a LaTeX distribution on TeX Live on most Linux distributions. Most LaTeX editors run natively on Linux without issues such as TeXstudio.")
    elif 4 in usecases:
        print("Most classic card games (e.g. Solitaire, Freecell, Spider Solitaire, etc.) can be played on Linux via apps like GNOME Aisleriot or KPat. Mahjongg can be played on Linux via apps like GNOME Mahjongg or KMahjongg. Chess and Minesweeper have Linux alternatives, too. If you like puzzle games, you can probably find plenty of those on Facebook, in your distro's app store, or in the Steam store.")
    elif 8 in usecases:
        print("Most mathematics, statistics and data science packages can run natively on Linux, including: GNU Octave, Maple, Mathematica, MATLAB, Maxima, PSPP, Python and its libraries, R and its libraries, Sagemath, SAS, Scilab, and WolframAlpha.")
    elif 9 in usecases:
        print("Most chemistry packages work on Linux. ACD/ChemSketch, Avogadro, BIOVIA Discovery Studio Visualizer, ChemDoodle, ChemDraw, enCIFer, Jmol, Ketcher, MarvinSketch, Mercury, MolSketch, OpenBabel, and PyMOL are all apps I have personally run on Linux. ACD/ChemSketch and ChemDraw do not run natively on Linux, but can be run via Wine. The others run natively on Linux. BIOVIA Draw is one chemistry app I failed to run on Linux.")
    elif 10 in usecases:
        print("Most code editors will run fine on Linux. The main exception that comes to my mind is Visual Studio. Antigravity, GNU Emacs, Neovim, Vim, Visual Studio Code and Zed will all run natively on Linux, however. Most compilers (e.g. Clang and GCC), debuggers (e.g. GNU GDB and strace) and interpreters (e.g. for Node.js, Perl, Python and Ruby) can also be obtained on Linux.")
    
def main():
    print("Linux Distribution Chooser\n")
    
    prompt_willingness = ("How willing are you, on a scale from 0 to 10, to spend time learning about Linux?\n"
              "0 would indicate you are completely unwilling to learn.\n"
              "5 would indicate that you're willing to spend maybe a few hours learning Linux before you will need to have a functioning system to show for it.\n"
              "10 would indicate you're willing to spend as much time as it takes,\n"
              "even if you are left without a functioning system for days until you complete that learning.\n"
              "> ")
    
    willingness = get_valid_input(prompt_willingness, 0, 10)
    
    prompt_usecase = ("Which of the following categories describe your computer use best? Please just enter the associated number(s) separated by spaces.\n"
    "0: Browsing the web and/or accessing emails.\n"
    "1: Basic office work: writing documents, spreadsheets or slideshows without much need for advanced control over formatting and exporting in Microsoft 365 formats.\n"
    "2: Intermediate office work: writing documents, spreadsheets or slideshows with some need for advanced control over formatting and exporting in Microsoft 365 formats.\n"
    "3: Advanced office work: writing documents, spreadsheets or slideshows in LaTeX.\n"
    "4: Basic gaming: Playing games, outside of your web browser (Facebook games would not count), without 3D graphics like card games.\n"
    "5: Advanced gaming: Playing games, outside of your browser, with 3D graphics. Examples are Minecraft, League of Legends, Baldur's Gate, Genshin Impact, RuneScape, World of Warcraft, etc.\n"
    "6: Creative work: photo editing, graphic design and video editing.\n"
    "7: Computer-assisted design: CAD, 2D and 3D modelling.\n"
    "8: Mathematics work: running simulations, data analysis, or running complex calculations.\n"
    "9: Chemistry work: creating chemical structure models or formulas, or running chemical calculations or simulations.\n"
    "10: Development: programming, debugging, testing and version control.\n"
    "> ")
    
    usecases = get_multiple_valid_inputs(prompt_usecase, 0, 10)
    
    recommend_distro(willingness, usecases)

if __name__ == "__main__":
    main()
