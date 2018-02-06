#!/bin/bash

echo -e "\nPreparing code basis for a new module:\n"

# Ask for module name:
read -p "Name of the module? " MODNAME

# Ask for module type:
echo -e "Type of the module?\n"
type=0
select yn in "unique" "detector"; do
    case $yn in
        unique ) type=1; break;;
        detector ) type=2; break;;
    esac
done

# Ask for the message type to run over
echo ""
read -p "Input message type? " MESSAGETYPE

# Check that message type exists
OBJDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )"
OBJDIR=$OBJDIR/../../src/objects
if [ ! -e ${OBJDIR}/${MESSAGETYPE}.hpp ]
then
  echo -e "\nMessage type ${MESSAGETYPE} does not exist. \nPlease see the message types in ${OBJDIR}\n"
  exit
fi

echo "Creating directory and files..."

echo
# Try to find the modules directory:
BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )"
DIRECTORIES[0]="${BASEDIR}/../../src/modules"
DIRECTORIES[1]="../src/modules"
DIRECTORIES[2]="src/modules"

MODDIR=""
for DIR in "${DIRECTORIES[@]}"; do
    if [ -d "$DIR" ]; then
	MODDIR="$DIR"
	break
    fi
done

# Create directory
mkdir "$MODDIR/$MODNAME"

# Copy over CMake file and sources from Dummy:
sed -e "s/Dummy/$MODNAME/g" $MODDIR/Dummy/CMakeLists.txt > $MODDIR/$MODNAME/CMakeLists.txt

# Copy over the README, setting current git username/email as author
# If this fails, use system username and hostname
MYNAME=$(git config user.name)
MYMAIL=$(git config user.email)
if [ -z "$MYNAME" ]; then
    MYNAME=$(whoami)
fi
if [ -z "$MYMAIL" ]; then
    MYMAIL=$(hostname)
fi
sed -e "s/Dummy/$MODNAME/g" \
    -e "s/\*NAME\*/$MYNAME/g" \
    -e "s/\*EMAIL\*/$MYMAIL/g" \
    -e "s/Functional/Immature/g" \
    "$MODDIR/Dummy/README.md" > "$MODDIR/$MODNAME/README.md"

# Copy over source code skeleton:
sed -e "s/Dummy/$MODNAME/g" "$MODDIR/Dummy/DummyModule.hpp" > "$MODDIR/$MODNAME/${MODNAME}Module.hpp"
sed -e "s/Dummy/$MODNAME/g" "$MODDIR/Dummy/DummyModule.cpp" > "$MODDIR/$MODNAME/${MODNAME}Module.cpp"

# Change to detetcor module type if necessary:
if [ "$type" == 2 ]; then

  # Options for sed vary slightly between mac and linux
  opt=-i
  platform=`uname`
  if [ "$platform" == "Darwin" ]; then opt="-i \"\""; fi

  # Prepare sed commands to change to per detector module
  # Change module type in CMakeLists
  command="sed $opt 's/_UNIQUE_/_DETECTOR_/g' $MODDIR/$MODNAME/CMakeLists.txt"
  eval $command
  # Change header file
  command="sed ${opt} \
      -e 's/ unique / detector-specific /g' \
      -e 's/param geo_manager.*/param detector Pointer to the detector for this module instance/g' \
      -e 's/GeometryManager\* geo\_manager/std::shared\_ptr\<Detector\> detector/g' \
      -e 's/GeometryManager/DetectorModel/g' \
      -e 's/std::vector<std::shared_ptr<PixelHitMessage>> messages_/std::shared_ptr<PixelHitMessage> message_/g' \
      -e 's/PixelHit/${MESSAGETYPE}/g' \
      $MODDIR/$MODNAME/${MODNAME}Module.hpp"
  eval $command
  # Change implementation file
  command="sed ${opt} \
      -e 's/GeometryManager\* geo_manager/std::shared\_ptr\<Detector\> detector/g' \
      -e 's/Module(std::move(config))/Module\(std::move(config)\, detector\)/g' \
      -e 's/bindMulti/bindSingle/g' \
      -e 's/messages_/message_/g' \
      -e '/for(auto/d' \
      -e 's/message->get/message_->get/g' \
      -e 's/geo_manager_(geo_manager)/detector_(detector)/g' \
      -e '/geo_manager_/d' \
      -e 's/detector->get/detector_->get/g' \
      -e '/    }/d' \
      -e '/Loop/d' \
      $MODDIR/$MODNAME/${MODNAME}Module.cpp"
  eval $command
fi

echo "Name:   $MODNAME"
echo "Author: $MYNAME ($MYMAIL)"
echo "Path:   $MODDIR/$MODNAME"
echo
echo "Re-run CMake in order to build your new module."
