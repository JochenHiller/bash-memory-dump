#!/bin/sh

# This is a modified version of memory-dump.sh to allow to run on plain bourne shell
# on embedded devices like OpenWRT or similar, where standard Linux commands are missing.

# Changes made:
# - use /bin/sh
# - removed COLOR_* support completely
# - determine OS_PAGESIZE via /proc if getconf is missing, needs parsed PID
# - don't check on root, better check if we can access /proc/<pid>
#   (in case we need to su to user owning process)
#   e.g. su jvm -s /bin/sh -c "./memory-dump-sh.sh -p 12345 -m all -d dd"
# - change if conditions to be sh compliant
# - minor improvements in error handling and verbose output


#
# FILE                      : memory-dump.sh
# VERSION                   : 0.3
# DESC                      : Linux process memory dumper in BASH
# REQUIREMENTS (gdb method) : BASH, AWK, SED, GDB, root permissions
# REQUIREMENTS (dd method)  : BASH, AWK, SED, DD, root permissions
# DATE                      : 2016
# AUTHOR                    : LALA -> lala (at) linuxor (dot) sk
#
##################################################################################
#                                   SCRIPT HISTORY
##################################################################################
#
# 03.12.2016 - Version 0.0 - First working prototype (gdb method).
# 04.12.2016 - Version 0.1 - Implemented memory dump with 'gdb' method.
# 06.12.2016 - Version 0.2 - Implemented memory dump with 'dd' method.
# 07.12.2016 - Version 0.3 - Refactoring.
#

##################################################################################
#                                    SCRIPT TODO
##################################################################################
#
# 1. Remove dependencies on SED (ideally also on AWK, but this is probably utopia).
# 2. In the name of memory file dump with DD method leading '0' (Hexa) is missing
#    thus file names with GDB and DD method are slightly different.
# 3. Maybe translate all comments to english language.
# 4. For correct/consistent memory dump with 'dd' method is necessary to implement
#    sending STOP (before dump activity) and CONTINUE (after dump activity) signals.
#
#    Memory of the process is very dynamic by nature thus for correct memory dump 
#    is necessary to send signal STOP to process (PID) for which we do memory dump. 
#    Signal STOP detach standard input/output of the process from the shell and 
#    then process (PID) is running as background process (of the shell). This is 
#    problem for processes as Midnight Commander (mc) because after we send signal 
#    CONTINUE (SIGCONT) process continue operation as background process but 
#    standard input/output is lost and is necessary to do some activity do bring 
#    "mc" user gui to work again. Actually memory dump with dd method works without 
#    signalling (STOP, CONTINUE) dumped process. Reatach standard input/output
#    of the process is trivial in language as C but is tricky (maybe impossible) 
#    in pure BASH.
#

##################################################################################
#                                     VARIABLES
##################################################################################

# GLOBALNE PREMENNE
# GLOBAL VARIABLES
NO_ARGS=0
SCRIPT_VERSION=0.3
SCRIPT_AUTHOR="LALA -> lala (at) linuxor (dot) sk"
SCRIPT_YEAR="2016"





##################################################################################
#                                     FUNCTIONS
##################################################################################

# Print usage message
function print_usage ()
{
    printf "%s\n" "Usage: `basename $0` [options]"
    printf "%s\n" "       -p PID              Dump memory region of the process which is specified by PID."
    printf "%s\n" "       -m MEMORY_REGION    Dump memory region of process (stack, heap, anon, all)."
    printf "%s\n" "       -d DUMP_METHOD      Dump memory method for dumping (gdb, dd)."
    printf "%s\n" "       -v                  Show script version."
}

# Print script version
function print_version ()
{
    printf "%s\n" "`basename $0` $SCRIPT_VERSION ($SCRIPT_YEAR)"
}

# Print dumping start message
function print_dump_start ()
{
    printf "%s"    ""
    printf "%s \n" "-----------------------------------------"
    printf "%s \n" "Process of dumping memory was started ..."
    printf "%s \n" "-----------------------------------------"
    printf "PROCESS (PID) :%s $PID %s\n"
    printf "MEMORY_REGION :%s $MEMORY_REGION %s\n"
    printf "DUMP_METHOD   :%s $DUMP_METHOD %s\n"
    printf "%s \n" "-----------------------------------------"
    printf "%s \n" "Dumping ..."
    printf "%s"    ""
}

# Print dumping end message
function print_dump_end ()
{
    local PID=$1
    local MEMORY_REGION=$2
    local DUMP_METHOD=$3
    local OUTPUT_DIRECTORY=$4

    printf "%s"
    printf "%s \n" "-----------------------------------------"
    printf "MEMORY REGION '%s' of process with PID='%s' was dumped with DUMP_METHOD='%s' to directory '%s'.\n" $MEMORY_REGION $PID $DUMP_METHOD $OUTPUT_DIRECTORY
    printf "%s \n" "-----------------------------------------"
    printf "%s"
}

# Print dumped files
function print_dump_files ()
{
    local OUTPUT_DIRECTORY=$1

    printf "%s"
    printf "%s \n" "LIST OF DUMPED FILES:"
    printf "%s"
    for dumpfile in $(ls $OUTPUT_DIRECTORY);
    do
        du -sh "$OUTPUT_DIRECTORY/$dumpfile";
    done | sort
    printf "%s"
}

# Dump selected memory region/regions with GDB method
function dump_gdb_region ()
{
    local PID=$1
    local PID_MAPS=$2
    local PID_MEM=$3
    local MEMORY_REGION=$4
    local OUTPUT_DIRECTORY=$5

    # vylistujeme vsetky pamatove oblasti s pravami "rw-p", cize uzivatelske/programove data (grep)
      # z vystupu vyparsujeme len ten pamatovy region o ktory sa zaujimame (grep)
        # vo vystupe nahradime znak '-' prazdnym znakom ' ' (sed)
          # spustime AWK
          # - pricom mu ako AWK parameter (pid) predame BASH parameter (PID)
          # - pricom mu ako AWK parameter (outdir) predame BASH parameter (OUTPUT_DIRECTORY)
          # - a spustime AWK kod (awk)
          #AWK# spustime debugger (gdb)
          #AWK# v davkovom rezime (--batch)
          #AWK# pripojime sa na proces s PID=$PID (--pid $PID)
          #AWK# vyvolame spustenie gdb prikazu (-ex)
          #AWK# pricom gdb prikaz vyzera nasledovne -> "dump memory ./MEMDUMPS-PID/bf94f000-bf970000.dump 0xbf94f000 0xbf970000"
          #AWK# do suboru "./MEMDUMPS-PID/bf94f000-bf970000.dump" sa ulozi mapatova oblast, ktora sa zacina na 
          #AWK# adrese 0xbf94f000 a konci na adrese 0xbf970000
            # vystup posleme do prikazove interpretra na vykonanie (sh)
    grep rw-p /proc/$PID/maps | 
      grep $MEMORY_REGION | 
        sed 's/-/ /g' | 
          awk -v pid="$PID" -v outdir="$OUTPUT_DIRECTORY" '{print "gdb --batch --pid "pid" -ex \42dump memory "outdir"/"$1"-"$2".dump 0x"$1" 0x"$2"\42 >/dev/null 2>&1"}' |
            sh
}

# Dump all memory regions with GDB method
function dump_gdb_all ()
{
    local PID=$1
    local PID_MAPS=$2
    local PID_MEM=$3
    local OUTPUT_DIRECTORY=$4

    # vylistujeme vsetky pamatove oblasti s pravami "rw-p", cize uzivatelske/programove data (grep)
      # vo vystupe nahradime znak '-' prazdnym znakom ' ' (sed)
        # spustime AWK
        # - pricom mu ako AWK parameter (pid) predame BASH parameter (PID)
        # - pricom mu ako AWK parameter (outdir) predame BASH parameter (OUTPUT_DIRECTORY)
        # - a spustime AWK kod (awk)
        #AWK# spustime debugger (gdb)
        #AWK# v davkovom rezime (--batch)
        #AWK# pripojime sa na proces s PID=$PID (--pid $PID)
        #AWK# vyvolame spustenie gdb prikazu (-ex)
        #AWK# pricom gdb prikaz vyzera nasledovne -> "dump memory ./MEMDUMPS-PID/bf94f000-bf970000.dump 0xbf94f000 0xbf970000"
        #AWK# do suboru "./MEMDUMPS-PID/bf94f000-bf970000.dump" sa ulozi mapatova oblast, ktora sa zacina na 
        #AWK# adrese 0xbf94f000 a konci na adrese 0xbf970000
          # vystup posleme do prikazove interpretra na vykonanie (sh)
    grep rw-p /proc/$PID/maps | 
      sed 's/-/ /g' | 
        awk -v pid="$PID" -v outdir="$OUTPUT_DIRECTORY" '{print "gdb --batch --pid "pid" -ex \42dump memory "outdir"/"$1"-"$2".dump 0x"$1" 0x"$2"\42 >/dev/null 2>&1"}' |
          sh
}

# Dump selected memory region/regions with DD method
function dump_dd_region ()
{
    local PID=$1
    local PID_MAPS=$2
    local PID_MEM=$3
    local MEMORY_REGION=$4
    local OUTPUT_DIRECTORY=$5

    # Not implemented, see SCRIPT TODO number 4 for more details.
    # Send STOP signal (SIGSTOP) to process (PID)
    # kill -SIGSTOP $PID

    # Do premennej range si ulozime zaciatocnu a konecnu adresu pamatovej oblasti
    # Citame z pseudo suboru "/proc/PID/maps" (pamatova mapa procesu)
    grep rw-p $PID_MAPS |
    grep $MEMORY_REGION |
    while IFS='' read -r line || [[ -n "$line" ]]; do

        # Zaznacime si pamatovy rozsah virtualnej pamatovej oblasti (VMA=Virtual Memory Area)
        local range=`echo $line | awk '{print $1;}'`

        # Zaznacime si startovaciu a konecnu adresu virtualnej pamatovej oblasti (VMA)
        local vma_start=$(( 0x`echo $range | cut -d- -f1` ))
        local vma_end=$(( 0x`echo $range | cut -d- -f2` ))
        local vma_size=$(( $vma_end - $vma_start ))

        # Premenime hodnoty z jednotiek stranok (vma) na jednotky poctu (count) blokov
        local dd_start=$(( $vma_start / $OS_PAGESIZE ))
        local dd_bs=$OS_PAGESIZE
        local dd_count=$(( $vma_size / $OS_PAGESIZE ))

        # set +e sets error ignoring state
        set +e
        dd if="$PID_MEM" bs="$dd_bs" skip="$dd_start" count="$dd_count" of="$OUTPUT_DIRECTORY/`printf '%x' $vma_start`-`printf '%x' $vma_end`.dump" 2>/dev/null
        # set -e sets an non-ignoring error state.
        set -e
    done

    # As mentioned higher this is actually not implemented.
    # Send STOP signal (SIGSTOP) to process (PID)
    # kill -SIGCONT $PID
}

# Dump all memory regions with DD method
function dump_dd_all ()
{
    local PID=$1
    local PID_MAPS=$2
    local PID_MEM=$3
    local OUTPUT_DIRECTORY=$4

    # Not implemented, see SCRIPT TODO number 4 for more details.
    # Send STOP signal (SIGSTOP) to process (PID)
    # kill -SIGSTOP $PID

    # Do premennej range si ulozime zaciatocnu a konecnu adresu pamatovej oblasti
    # Citame z pseudo suboru "/proc/PID/maps" (pamatova mapa procesu)
    grep rw-p $PID_MAPS |
    while IFS='' read -r line || [[ -n "$line" ]]; do

        # Zaznacime si pamatovy rozsah virtualnej pamatovej oblasti (VMA=Virtual Memory Area)
        local range=`echo $line | awk '{print $1;}'`

        # Zaznacime si startovaciu a konecnu adresu virtualnej pamatovej oblasti (VMA)
        local vma_start=$(( 0x`echo $range | cut -d- -f1` ))
        local vma_end=$(( 0x`echo $range | cut -d- -f2` ))
        local vma_size=$(( $vma_end - $vma_start ))

        # Premenime hodnoty z jednotiek stranok (vma) na jednotky poctu (count) blokov
        local dd_start=$(( $vma_start / $OS_PAGESIZE ))
        local dd_bs=$OS_PAGESIZE
        local dd_count=$(( $vma_size / $OS_PAGESIZE ))

        # set +e sets error ignoring state
        set +e
        dd if="$PID_MEM" bs="$dd_bs" skip="$dd_start" count="$dd_count" of="$OUTPUT_DIRECTORY/`printf '%x' $vma_start`-`printf '%x' $vma_end`.dump" 2>/dev/null
        # set -e sets an non-ignoring error state.
        set -e
    done

    # As mentioned higher this is actually not implemented.
    # Send STOP signal (SIGSTOP) to process (PID)
    # kill -SIGCONT $PID
}


##################################################################################
#                               CHECK ENVIRONMENT
##################################################################################



##################################################################################
#                                     PARSE ARGUMENTS
##################################################################################

##################################### Check script arguments
if [ $# -eq "$NO_ARGS" ]
then
    print_usage
    exit 1
fi

if [ $# -lt 6 ]
then
    print_usage
    printf "\nRequired options are -p PID -m MEMORY_REGION -d DUMP_METHOD\n"
    exit 1
fi


##################################### Process script arguments
while getopts ":p:d:m:v" Option
do
    case $Option in


##################################### Argument "-p PID"
##################################### Dump memory for PID (process)
    p)
    # Skontrolujeme ci proces specifikovany jeho PID cislom existuje
    if kill -0 ${OPTARG} 2>/dev/null
    then
        # Do premennej PID si ulozime druhy argument volby -p (cize PID procesu)
        PID=${OPTARG}
    else
        # Inak vypiseme chybove hlasenie o neexistencii PID a skoncime s chybou
        printf "PID not exist.\n"
        exit 1
    fi
    ;;


##################################### Argument "-d DUMP_METHOD"
##################################### Set memory dumping method ("gdb", "dd")
    d)
    # Skontrolujeme ci uzivatel zadal jednu z povolenych metod (gdb | dd)
    if [[ ${OPTARG} != "gdb"  &&  ${OPTARG} != "dd" ]]
    then
        echo "Option argument to '-d' can only by 'gdb' or 'dd'."
        exit 1
    else
        # Nastavime dump metodu
        DUMP_METHOD=${OPTARG}
    fi
    ;;


##################################### Argument "-m MEMORY_REGION"
##################################### Set memory region for dumping ("stack", "heap", "anon", "all")
    m)
    # Skontrolujeme ci uzivatel zadal jeden z povolenych pamatovych regionov (stack | heap | anon | all)
    if [[ ${OPTARG} != "stack"  &&  ${OPTARG} != "heap"  &&  ${OPTARG} != "anon"  &&  ${OPTARG} != "all" ]]
    then
        echo "Option argument to '-m' can only by 'stack', 'heap', 'anon' or 'all'."
        exit 1
    else
        # Nastavime pamatovy region
        MEMORY_REGION=${OPTARG}
    fi
    ;;


##################################### Argument "-v"
##################################### Show script version
    v)
    print_version
    exit 0
    ;;


##################################### Default
##################################### Show usage
    *)
    print_usage
    printf "\nRequired options are -p PID -m MEMORY_REGION -d DUMP_METHOD\n"
    exit 0
    ;;


    esac
done

# check for missing args, if we have 6, but invalid args
if [ "$PID" == "" -o "$MEMORY_REGION" = "" -o "" = "$DUMP_METHOD" ]
then
    print_usage
    printf "\nRequired options are -p PID -m MEMORY_REGION -d DUMP_METHOD\n"
    exit 1
fi

# Dekrementujeme smernik argumentu, takze ukazuje na nasledujuci parameter.
# $1 teraz referuje na prvu polozku (nie volbu) poskytnutu na prikazovom riadku.
shift $(($OPTIND - 1))

######################### calc pagesize now if we know pid
OS_PAGESIZE=$(getconf PAGESIZE 2>/dev/null)
rc=$?
if [ "${rc}" = "0" ] ; then
  echo "INFO  OS_PAGESIZE=${OS_PAGESIZE}"
else
  # get pagesize from /proc if there is not getconf
  # https://stackoverflow.com/questions/4888067/how-to-get-linux-kernel-page-size-programmatically
  kernel_page_size_in_k=$(cat /proc/${PID}/smaps | grep KernelPageSize | head -1 | sed -e 's|[A-Za-z_= :]*||g')
  kernel_page_size=$((${kernel_page_size_in_k} * 1024))
  OS_PAGESIZE=${kernel_page_size}
  echo "WARN  Could not getconf pagesize: determined pagesize is ${OS_PAGESIZE}"
fi



##################################################################################
#                              PREPARE ENVIRONMENT
##################################################################################

# Maps and Mem file of the process (PID)
PID_MAPS="/proc/$PID/maps"
PID_MEM="/proc/$PID/mem"

##################################### Check if we can access /proc/<pid>
# check if $PID_MAPS and $PID_MEM can be accessed
access_not_possible=false
cat $PID_MAPS >/dev/null 2>&1
rc=$?
if [ ! "${rc}" = "0" ] ; then
  access_not_possible=true
fi
cat $PID_MEM >/dev/null 2>&1
if [ ! "${rc}" = "0" ] ; then
  access_not_possible=true
fi
if [ "${access_not_possible}" = "true" ] ; then
  echo "ERROR Could not access $PID_MAPS or $PID_MEM"
  exit 2
fi

##################################### Check output directory (If not exists then create)
OUTPUT_DIRECTORY="./MEMDUMPS-of-PID-$PID"

# If OUTPUT_DIRECTORY exists then remove it completely
if [ -d $OUTPUT_DIRECTORY ]
then
    echo "INFO  Cleaning up $OUTPUT_DIRECTORY"
    rm -rf $OUTPUT_DIRECTORY
fi

# Create clean OUTPUT_DIRECTORY
mkdir -p $OUTPUT_DIRECTORY


##################################################################################
#                                     MAIN
##################################################################################

case $DUMP_METHOD in

##################################### Argument "-d gdb"
##################################### Dump method = gdb
    gdb)
    # Ak sa jedna o pamatovy region "stack" alebo "heap" alebo "anon"
    if [[ $MEMORY_REGION == "stack"  ||  $MEMORY_REGION == "heap"  ||  $MEMORY_REGION == "anon" ]]
    then
        print_dump_start
        dump_gdb_region $PID $PID_MAPS $PID_MEM $MEMORY_REGION $OUTPUT_DIRECTORY
        print_dump_end $PID $MEMORY_REGION $DUMP_METHOD $OUTPUT_DIRECTORY
        print_dump_files $OUTPUT_DIRECTORY

    # Inak sa jedna o vsetky (all) pamatove regiony
    else
        print_dump_start
        dump_gdb_all $PID $PID_MAPS $PID_MEM $OUTPUT_DIRECTORY
        print_dump_end $PID $MEMORY_REGION $DUMP_METHOD
        print_dump_files $OUTPUT_DIRECTORY
    fi
    exit 0
    ;;

##################################### Argument "-d dd"
##################################### Dump method = dd
    dd)
    # Ak sa jedna o pamatovy region "stack" alebo "heap" alebo "anon"
    if [[ $MEMORY_REGION == "stack"  ||  $MEMORY_REGION == "heap"  ||  $MEMORY_REGION == "anon" ]]
    then
        print_dump_start
        dump_dd_region $PID $PID_MAPS $PID_MEM $MEMORY_REGION $OUTPUT_DIRECTORY
        print_dump_end $PID $MEMORY_REGION $DUMP_METHOD $OUTPUT_DIRECTORY
        print_dump_files $OUTPUT_DIRECTORY
    # Inak sa jedna o vsetky (all) pamatove regiony
    else
        print_dump_start
        dump_dd_all $PID $PID_MAPS $PID_MEM $OUTPUT_DIRECTORY
        print_dump_end $PID $MEMORY_REGION $DUMP_METHOD $OUTPUT_DIRECTORY
        print_dump_files $OUTPUT_DIRECTORY
    fi

esac


# Uspesny koniec
exit 0
