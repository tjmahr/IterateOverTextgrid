# --------------------------------------------------------------------------------------
# Helpers from https://gitlab.com/cpran/plugin_selection/blob/master/procedures/tiny.proc

#! ---
#! title:  'Lightweight procedures'
#! author:
#! - 'José Joaquín Atria'
#! tags: [praat, cpran, selection]
#! abstract: |
#!   This is a set of procedure that make it easy to save and restore
#!   any number of object selections, as well as perform other related
#!   tasks (clear the selection, count types of objects, etc).
#!
#!   This script is part of the selection CPrAN plugin for Praat.
#! ---
#!
#! These procedures do not use selection tables
#!
#! ## License
#!
#! This script is part of the selection CPrAN plugin for Praat.
#! The latest version is available through CPrAN or at
#! <http://cpran.net/plugins/selection>
#!
#! The selection plugin is free software: you can redistribute it
#! and/or modify it under the terms of the GNU General Public
#! License as published by the Free Software Foundation, either
#! version 3 of the License, or (at your option) any later version.
#!
#! The selection plugin is distributed in the hope that it will be
#! useful, but WITHOUT ANY WARRANTY; without even the implied warranty
#! of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#! GNU General Public License for more details.
#!
#! You should have received a copy of the GNU General Public License
#! along with selection. If not, see <http://www.gnu.org/licenses/>.
#!
#! Copyright 2014, 2015 Jose Joaquin Atria

# Setting this variable to 0 makes the selection process much more
# stringent.
if !variableExists("selection.restore_nocheck")
  selection.restore_nocheck = 1
endif

#!
#! ## Procedures
#!

## Selection tables

#! ### `saveSelection` {#save-selection}
#!
#! ~~~ params
#! out:
#!   - .n: The total number of selected objects
#!   - .id[]: >
#!     An indexed variable with the ID numbers of each originally
#!     selected object
#! ~~~
#!
#! Save the active selection.
#!
#! The selection is saved in the internal indexed variable `.id[]`,
#! which is accessed internally by [`restoreSelection()`]
#! (#restore-selection) to restore this anonymous selection.
#!
#! Since the selection is _anonymous_, and not saved anywhere external,
#! this selection is _extremely_ fragile. If there is _any_
#! chance this procedure might be called again before the enxt call
#! to [`restoreSelection()`](#restore-selection), then prefer
#! [`saveSelectionTable()`](save-selection-table).
#!
procedure saveSelection ()
  .n = numberOfSelected()
  for .i to .n
    .id[.i] = selected(.i)
  endfor

  @restoreSelection()
endproc


#! ### `restoreSelection` {#restore-selection}
#!
#! ~~~ params
#! selection:
#!   out: true
#! ~~~
#!
#! Restores the last selection saved by [`saveSelection`](#save-selection).
#!
#! Upon being called, this will restore the selection available in the
#! internal variables of [`saveSelection`](#save-selection).
#!
procedure restoreSelection ()
  if variableExists("saveSelection.n")
    nocheck selectObject: undefined
    @plusSelection()
  else
    exitScript: "No selection saved"
  endif
endproc


#! ### `plusSelection` {#plus-selection}
#!
#! ~~~ params
#! selection:
#!   out: true
#! ~~~
#!
#! Adds the last selection saved by [`saveSelection()`](#save-selection)
#! to the current selection.
#!
#! Similar to calling [`restoreSelection()](restore-selection), but the
#! selection is not cleared first.
#!
procedure plusSelection ()
  if variableExists("saveSelection.n")
    for .i to saveSelection.n
      if selection.restore_nocheck
        nocheck plusObject: saveSelection.id[.i]
      else
        plusObject: saveSelection.id[.i]
      endif
    endfor
  else
    exitScript: "No selection saved"
  endif
endproc

#! ### `minusSelection` {#minus-selection}
#!
#! ~~~ params
#! selection:
#!   out: true
#! ~~~
#!
#! Removes objects in the last selection saved by
#! [`saveSelection()`](save-selection) from the current selection
#!
procedure minusSelection ()
  if variableExists("saveSelection.n")
    for .i to saveSelection.n
      if selection.restore_nocheck
        nocheck minusObject: saveSelection.id[.i]
      else
        minusObject: saveSelection.id[.i]
      endif
    endfor
  else
    exitScript: "No selection saved"
  endif
endproc

# --------------------------------------------------------------------------------------




# Other helpers ------------------------------------------------------------------------

# An iterator for a list of strings
# See https://github.com/tjmahr/2015_Coartic/blob/master/phonetics/utils/iter.praat
procedure strings_iter(.list$, .method$)
    selectObject: "Strings '.list$'"
    
    if .method$ = "initialize"
        .'.list$'.length = Get number of strings
        .'.list$'.index = 0
    endif
    
    if .method$ = "next"
        .'.list$'.index = .'.list$'.index + 1
        .'.list$'.next$ = Get string: .'.list$'.index
    endif

    
    if .method$ = "has_next"
        # .has_next is updated whenever procedure is invoked
    endif
    
    if .'.list$'.index < .'.list$'.length
        .'.list$'.has_next = 1
    else
        .'.list$'.has_next = 0
    endif
endproc

procedure measureNonPauses: .durTableName$, .basename$, .tierName$, .silencePattern$
	.soundName$ = "Sound '.basename$'"
	.tgName$ = "TextGrid '.basename$'"

	selectObject: .tgName$

	@findTierWithName: .tgName$, .tierName$
	.tierNum = findTierWithName.result

	selectObject: .tgName$
	.numInts = Get number of intervals: .tierNum 

	# Clean slate with no objects selected
	minusObject: .tgName$
	@saveSelection()

	# Loop through each interval
	for .intNum from 1 to .numInts
		# Get some information about the interval	
		selectObject: .tgName$
		.intText$ = Get label of interval: .tierNum, .intNum 
		.currentIntervalName$ = .basename$ + "_" + string$(.tierNum) + "_" + string$(.intNum)
		.tmin = Get start point: .tierNum, .intNum 
		.tmax = Get end point: .tierNum, .intNum 

		# Is this interval 150 ms long?
		.duration = .tmax - .tmin
		.shortDuration = .duration <= 0.15

		# Is it coded as a space
		.isSpace = .intText$ == "sp"
		.isLongSpace = .isSpace and !.shortDuration
		
		if .isLongSpace 	
			@appendLogLine: "skipping SP interval with long duration ['.duration']"
		endif


	        # Does the interval text contain one of the silence codes

		.isNotSilence = index_regex(.intText$, .silencePattern$) == 0

		if .isNotSilence and !.isLongSpace
			@appendLogLine: "extracting interval with text ['.intText$']"

			# Extract the sound in it
			selectObject: .soundName$
			Extract part: .tmin, .tmax, "rectangular", 1, "no"
			Rename: .currentIntervalName$

			# Add the part to our rolling collection of sounds
			@restoreSelection()
			plusObject: "Sound '.currentIntervalName$'"
			@saveSelection()
		endif

	endfor

	# Update table if we could extract pieces
	@restoreSelection()

	if saveSelection.n != 0
		.combinedName$ = .basename$ + "_combined"
		.combinedSoundName$ = "Sound " + .combinedName$

		Concatenate
		Rename: .combinedName$

		@updateDurationTable: .durTableName$, .basename$, .soundName$, .combinedSoundName$

		@restoreSelection()
		plusObject: .combinedSoundName$
		Remove
	endif

	@saveSelection()
endproc

procedure findTierWithName: .tgName$ .tierName$
	selectObject: .tgName$
	.numTiers = do("Get number of tiers")

	for i from 1 to .numTiers
		.currName$ = Get tier name: i
		if .currName$ = .tierName$
			.result = i
		endif
	endfor
endproc


procedure updateDurationTable: .durTableName$, .basename$, .rawSoundName$, .newSoundName$
	selectObject: .rawSoundName$
	.durationRaw = Get total duration
	.amplitudeRaw = Get intensity (dB)

	To Intensity: 100, 0, "yes"
	.maxIntensityRaw = Get maximum: 0, 0, "Parabolic"
	selectObject: "Intensity " + .basename$
	Remove

	selectObject: .newSoundName$
	.durationNew = Get total duration
	.amplitudeNew = Get intensity (dB)

	@appendLogLine: "updating '.durTableName$'"
	selectObject: .durTableName$
	Append row
	.currRows = Get number of rows
	

	Set string value: .currRows, "Token", .basename$
	Set numeric value: .currRows, "DurationRaw", .durationRaw
	Set numeric value: .currRows, "AmplitudeRaw", .amplitudeRaw
	Set numeric value: .currRows, "MaxAmplitudeRaw", .maxIntensityRaw
	Set numeric value: .currRows, "DurationNoPauses", .durationNew
	Set numeric value: .currRows, "AmplitudeNoPauses", .amplitudeNew
endproc

# Helpers for script logging

# Set the prefix of each log message
procedure setLogPrefix: .prefix$
	.result$ = .prefix$
endproc

# Update the log
procedure writeLogLine: .message$
	writeInfoLine: setLogPrefix.result$ + .message$
endproc

procedure appendLogLine: .message$
	appendInfoLine: setLogPrefix.result$ + .message$
endproc


# --------------------------------------------------------------------------------------



# Main script --------------------------------------------------------------------------

form Analyze tokens in a folder
	sentence directory_to_check C:\Users\Phoebe\Desktop\test-for-Tristan
	sentence where_to_save_table C:\Users\Phoebe\Desktop\test-for-Tristan
	word what_to_name_table_file durations
endform


# Get a list of wav files in a folder
sound_dir$ = directory_to_check$
Create Strings as file list: "fileList", sound_dir$ + "/*.wav"
@strings_iter: "fileList", "initialize"

# FYI to user
file_count = Get number of strings
@setLogPrefix: ".."
@writeLogLine: "searching " + sound_dir$
@appendLogLine: string$(file_count) + " wav files found"

# Table that will store the durations of tokens
durName$ = "TokenDurations"
durTableName$ = "Table 'durName$'"
Create Table with column names: durName$, 0, "Token DurationRaw AmplitudeRaw MaxAmplitudeRaw DurationNoPauses AmplitudeNoPauses"
@appendLogLine: "created Table " + durName$

tierToCheck$ = "words"
@appendLogLine: "tier to check ['tierToCheck$']"

# Pattern that means an interval is silent
# See http://www.fon.hum.uva.nl/praat/manual/Regular_expressions_1__Special_characters.html
# this says "sp" OR "sil" indicate silence
silencePattern$ = "^sil$"
@appendLogLine: "silence pattern ['silencePattern$']"




while strings_iter.fileList.has_next
	@setLogPrefix: "  .."

	# Get the next sound
	@strings_iter("fileList", "next")
	file$ = strings_iter.fileList.next$
	Read from file: sound_dir$ + "/" + file$
	@appendLogLine: "loaded " + file$

	token$ = selected$ ("Sound")
	textgrid$ = token$ + ".TextGrid"
	Read from file: sound_dir$ + "/" + textgrid$
	@appendLogLine: "loaded " + textgrid$
	
	@setLogPrefix: "    .."
	@measureNonPauses: durTableName$, token$, tierToCheck$, silencePattern$

	selectObject: "Sound 'token$'"
	plusObject: "TextGrid 'token$'"
	Remove
endwhile

@setLogPrefix: ".."

selectObject: "Strings fileList"
Remove

selectObject: "Table TokenDurations"
outfile$ = "'directory_to_check$'/'what_to_name_table_file$'.csv"
Save as comma-separated file: outfile$
Remove
@appendLogLine: "Saving 'outfile$'"



