!
! Copyright (C) 2016 - 2017 Michael A. Maedo
!
module file_mod

    use parameters_mod, only: ZERO
    
    use precision_mod, only: BYTE, LONG, DOUBLE                                              

    use string_mod, only: &
        & LEN_STR, &
        & LEN_NAME_FILE, &
        & MAX_LEN, &
        & split_txt_num, &
        & uppercase      

    use error_mod, only: &
        error, &
        & there_is_any_error, &
        & ERROR_INVALID_CARD,  &
        & ERROR_WORD_NOT_FOUND,  &
        & ERROR_SIZE_STRING_OF_NUM, &
        & ERROR_SIZE_STRING_OF_TXT,  & 
        & INFO_SIZE_STRING, &
        & ERROR_END_FILE, &
        & ERROR_OPEN_FILE, &
        & ERROR_3RD_PARAM

#include "error.fpp"
    
    implicit none

    type data_file
!        private
        integer(LONG) :: ID
        integer(LONG) :: line_number
        integer(LONG) :: ftype
        character(LEN = LEN_NAME_FILE) :: name
    end type data_file   
    
!    intrinsic trim, new_line
    
contains

    subroutine set_file_ID( file )
        type(data_file) :: file

        integer(LONG), save :: ID = 0
        
        ID = ID + 1
        file % ID = ID
    end subroutine set_file_ID

    
    subroutine set_file_name(filename, file)
        character(len = *), intent(in) :: filename
        type(data_file), intent(inout) :: file

        file % name = ''
        file % name = trim(filename)
    end subroutine set_file_name


    function get_file_ID( file ) result (ID)
        type(data_file), intent(in) :: file
        integer(LONG) :: ID

        ID = file % ID
    end function get_file_ID

    
    function get_file_name( file ) result (filename)
        type(data_file), intent(in) :: file
        character(len = :), allocatable :: filename

        filename = trim(file % name)
    end function get_file_name

    
    subroutine open_file(filename, file, in_out, err)
        character(len = *), intent(in) :: filename
        character(len = *), intent(in) :: in_out
        type(data_file), intent(out) :: file
        type(error), intent(inout) :: err

        character(len = MAX_LEN) :: errorMessage
        character(len = *), parameter :: endl = new_line('A')
        character(len = *), parameter :: tab = '    '

        call set_file_name(fileName, file)
        if (in_out == 'INPUT') then
            call open_input_file(file, err)
        else if (in_out == 'OUTPUT') then
            call open_output_file(file, err)
        else
            RAISE(ERROR_3RD_PARAM, err)
        end if

        errorMessage = tab//'The following file was not properly opened'//endl
        errorMessage = tab//trim(errorMessage)//endl            
        errorMessage = tab//trim(errorMessage)//fileName
        EXCEPT(errorMessage, ERROR_OPEN_FILE, err)
            
    end subroutine open_file
        

    subroutine open_input_file(inp_file, err)
        type(data_file), intent(inout) :: inp_file
        type(error), intent(inout) :: err
     
        integer(LONG) :: info
        integer(LONG), parameter :: INP = 0

        inp_file % ftype = INP
        call set_file_ID( inp_file )
        open(unit = inp_file % ID, file = trim(inp_file % name), iostat = info, &
            & status = 'old'  , access = 'sequential', action = 'read', &
            & delim  = 'none' , form   = 'formatted' , pad    = 'yes' , &
            & position = 'rewind')

        call check_error(info, err)

    end subroutine open_input_file

    
    subroutine open_output_file(out_file, err)
        type(data_file), intent(inout) :: out_file
        type(error), intent(inout) :: err 

        integer(LONG) :: info
        integer(LONG), parameter :: OUT = 1

        out_file % ftype = OUT
        call set_file_ID( out_file )
        open(unit = out_file % ID, file = trim(out_file % name), iostat = info ,&
            & status = 'replace' , access = 'sequential', action = 'write', &
            & delim  = 'none'    , form   = 'formatted' , pad    = 'yes'  , &
            & position = 'rewind')

        call check_error(info, err)

        return
    end subroutine open_output_file


    subroutine write_to_file( message, file )
        character(len = *), intent(in) :: message
        type(data_file), intent(in) :: file

        integer(LONG) :: ID

        ID = file % ID
        write(ID,*) message
    end subroutine write_to_file

    
    subroutine close_file(file)
        type(data_file), intent(inout) :: file
        close(unit = file % ID, status = 'keep')
    end subroutine close_file
    

    subroutine check_error(info, err)
        integer(LONG), intent(in) :: info
        type(error), intent(inout) :: err

        if ( there_is_any_error(info) ) then
            RAISE(ERROR_OPEN_FILE, err)
        end if

    end subroutine check_error


    !Read a line from input file and store the words in txt and the numerical values in num
    subroutine get_record(inp_file, txt, ntxt, num, nnum, err)
        
        type(data_file), intent(inout) :: inp_file !input file 
        type(error), intent(inout) :: err !(err % status /= NO_ZERO) means that an error has been detected in
!                                         one of the following subroutines: get_string or split_txt_num
        integer(LONG), intent(out) :: nnum !number of numerical values
        integer(LONG), intent(out) :: ntxt !number of strings     
        real(double), intent(out) :: num(:) !arrays of numerical values. It is obtained from the input file
        character(len = *), intent(out) :: txt(:) !array of the strings. It is obtained by reading the input file

        integer(LONG)            :: num_size, txt_size, nwords
        character(len = LEN_STR) :: string
        character(len = MAX_LEN) :: errorMessage
        logical                  :: new_lin
        integer(LONG), allocatable :: begin(:)
        integer(LONG), allocatable :: end_word(:)

        string = ''; txt = ''; num = ZERO; ntxt = 0; nnum = 0
        num_size = size(num); txt_size = size(txt)

        allocate( begin( num_size + txt_size ) )
        allocate( end_word( num_size + txt_size ) )

        do
!
            call get_string(inp_file, string, nwords, begin, end_word, new_lin, err)
            errorMessage = 'Unexpected end of file. Check file '//inp_file % name
            EXCEPT(errorMessage, ERROR_END_FILE, err)

            errorMessage = 'Programming error => GET_STRING: capacity of the array(s) BEGIN (and/or END_WORD) &
                &is (are) smaller than the number of words in the card'
            EXCEPT(errorMessage, INFO_SIZE_STRING, err)
!
!           Split string in texts and numerical values
            call split_txt_num(string, nwords, begin, end_word, txt, ntxt, num, nnum, err)
            
            errorMessage = 'Programming error => SPLIT_TXT_NUM: The number of numerical values in the string &
                &exceeds the dimension of the array'
            EXCEPT(errorMessage, ERROR_SIZE_STRING_OF_NUM, err)

            errorMessage = 'Programming error => SPLIT_TXT_NUM: The number of words in the string exceeds the &
                &dimension of the array of characters'
            EXCEPT(errorMessage, ERROR_SIZE_STRING_OF_TXT, err)

            if (.not.new_lin) exit
        end do
        return

    end subroutine get_record
    

    !Get a string from a file and compute the number of words in the string
    subroutine get_string( file, string, nwords, begin, end_word, &
        & line_flag, err, delimiter, comment, new_lin)
        
        type(data_file), intent(inout)        :: file !input file 
        type(error), intent(inout) :: err !(err % status == ERROR_END_FILE) means unexpected end of file; otherwise in ok    

        character(len = *), intent(in), optional :: delimiter !characters to be ignored in word count
        character(len = *), intent(in), optional :: comment !symbols that define when word count stops  
        character(len = *), intent(in), optional :: new_lin !characters that flags a new line
        
        integer(LONG)     , intent(out) :: nwords !number of words in str   
        character(len = *), intent(out) :: string !contain characters read from input file   
        logical           , intent(out) :: line_flag
        integer, intent(out) :: begin(:) !positions of the 1st char of each word in str
        integer, intent(out) :: end_word(:) !positions of the last char of each word in str          

        integer(LONG)             :: i, j
        integer(LONG)             :: info
        integer(LONG)             :: n_alpha_num
        character(len = BYTE)     :: charac
        character(len = LEN_STR)  :: delim, comme, nline
        logical                   :: delim_flag, lflag
!
!       Check if 'delimiter' is present
        if (present(delimiter)) then
            delim = delimiter
        else
            delim = ' ":;,='//char(9)//char(11)
        end if
!
!       Check if 'comment' is present
        if (present(comment)) then
            comme = comment
        else
            comme = '!@#%^&*()'
        end if
!
!       Check if 'new_lin' is present
        if (present(new_lin)) then
            nline = new_lin
        else
            nline = '/\'
        end if
!
!       Read a string from input file
        do
            lflag = .true.
!
!           Test for end of file
            read(file % ID, fmt = '(A)', iostat = info) string
            if ( there_is_any_error(info) ) then
                RAISE( ERROR_END_FILE, err )
            end if
!
!           Number of the current line in the input file
!           It is used in case of error occurrence
            file % line_number = file % line_number + 1            
!
!           Check if it is at least one alphanumeric character in 'string'
!           If there is none, then goes to the next iteration of the loop
            n_alpha_num = scan(uppercase(string), '1234567890ABCDEFGHI&
                                                  &JKLMNOPQRSTUVXWYZ')
            if (n_alpha_num == 0) cycle
!
!           If the string is commented from the beginning, the next line
!           the input file is read
            do i = 1, len_trim(comme)
                if (string(1:1) == comme(i:i)) then
                    lflag = .false.
                    exit
                end if
            end do
            if (lflag) exit
        end do
!
!       Variable initialization
        nwords = 0 ; begin = 0; end_word = 0; line_flag = .false.
!
!       Read the string, ignoring the characters in 'delim'
        do i = 1, len_trim(string)
!
            charac = string(i:i)
!
!           Check if charac is a comment
            do j = 1, len_trim(comme)
                if (charac == comme(j:j)) return
            end do
!
!           Check if charac is a delimiter
            delim_flag = .true.
            do j = 1, len_trim(delim)
                if (charac == delim(j:j)) then
                    delim_flag = .false.
                    lflag = .true.
                    exit
                end if
            end do
!
!           Check if charac flags a new line or not
            do j = 1, len_trim(nline)
                if (charac == nline(j:j)) then
                    line_flag = .true.
                    return
                end if
            end do
!
!           Find the position of a word in string
            if (delim_flag) then
                if (lflag) then
                    nwords = nwords + 1
!
!                   Test if the number of words is smaller than the capacity
!                   of 'begin' (and 'end_word')
                    if (nwords > size(begin) .or. nwords > size(end_word)) then
                        RAISE( INFO_SIZE_STRING, err )
                    end if

                    begin(nwords)    = i
                    end_word(nwords) = i !In case of a single char
                    lflag = .false.
                else
                    end_word(nwords) = i
                end if
            end if
        end do
        
    end subroutine get_string
        
end module file_mod
