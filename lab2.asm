;+--------------------------------------------------------------------------
; Эта TSR программа выводит окно средствами BIOS по нажатию F12
; выгрузка:
; >имяпрог /off (например: lab2 /off)
;+--------------------------------------------------------------------------
code_seg segment
        ASSUME  CS:CODE_SEG,DS:code_seg,ES:code_seg
	org 100h
start:
    jmp begin
;----------------------------------------------------------------------------
int_2Fh_vector  DD  ?
old_09h         DD  ?

;----------------------------------------------------------------------------
flag        DB  0
high_Y      DB  07	; координаты окна
left_X      DB  50	; координаты окна
low_Y       DB  15	; координаты окна
right_X     DB  69	; координаты окна
;
flag_klav db 0
time db 6,?,6 dup(0)
hours db 0
minutes db 0
page_num    DB  0
coord_Y     DB  11	; Y координата сообщения в окне
coord_X     DB  57	; X координата сообщения в окне
;============================================================================
new_09h proc far
;
    pushf
	push    AX
    in      AL,60h      ; Введем scan-code
	cmp CS:flag_klav,1
	je no
    cmp     AL,58h      ; Это скен-код <F12>
    je      hotkey      ; Yes
    pop     AX          ; No. Восстановим AX
	popf
	jmp     dword ptr CS:[old_09h]
	no:
	mov     AL, 20h      ; Пошлем
    out     20h,AL       ; приказ EOI
	push cx
	push dx
	mov AH, 2Ch
	int 21h
	push bx
	xor BX,BX
	xor AX,AX
	mov AL, 10
	mov BH, CS:time[2]
	mov BL, CS:time[3]
	mul BH
	add AL, BL
	cmp AL, CH
	ja finish
	xor BX,BX
	xor AX,AX
	mov AL,10
	mov BH, CS:time[5]
	mov BL, CS:time[6]
	mul BH
	add AL, BL
	cmp AL, CL
	ja finish
	mov CS:flag_klav,0
	pop BX
	pop dx
	pop cx
	pop AX
	popf
	jmp     dword ptr CS:[old_09h]
	finish:
	pop BX
	pop dx
	pop cx
	pop AX
	popf
	iret
hotkey:
    sti                 ; Не будем мешать таймеру
    in      AL,61h      ; Введем содержимое порта B
    or      AL,80h      ; Установим старший бит
    out     61h,AL      ; и вернем в порт B.
    and     AL,7Fh      ; Снова разрешим работу клавиатуры,
    out     61h,AL      ; сбросив старший бит порта B.
;
;-------------------- Вывод окна средствами BIOS ---------------------------
;
            push    BX	; сохранение используемых регистров в стеке
            push    CX	; сохранение используемых регистров в стеке
            push    DX	; сохранение используемых регистров в стеке
			push	DS	; сохранение используемых регистров в стеке
			;
			push	CS	;	настройка DS
			pop		DS	;				на наш сегмент, т.е DS=CS
;----------------------------------------------------------------------------
        mov     AX, 0600h      ; Задание окна
        mov     BH, 70h        ; Атрибут черный по серому
        mov     CH, CS:high_Y     ; Ко-
        mov     CL, CS:left_X     ;    ор-
        mov     DH, CS:low_Y      ;       ди-
        mov     DL, CS:right_X    ;          наты окна
        int 10h
;----------------------------------------------------------------------------
; ------------------------ Позиционируем курсор -----------------------------
        mov     AH,02h          ; Функция позиционирования
        mov     BH,CS:page_num  ; Видеостраница
        mov     DH,CS:coord_Y   ; Строка
        mov     DL,CS:coord_X   ; Столбец
        int 10h
			pop		DS	; восстановление регистров из стека в порядке LIFO
            pop     DX
            pop     CX
            pop     BX
;---------------------------------------------------------------------------
    mov     AL, 20h      ; Пошлем
    out     20h,AL       ; приказ EOI
	mov AX, CS
	mov DS, AX
	mov AH,0Ah
	mov DX, offset time
	int 21h
	sub CS:time[2], 30h
	sub CS:time[3], 30h
	sub CS:time[5], 30h
	sub CS:time[6], 30h
	mov CS:flag_klav,1 
    pop AX
	popf
    iret
new_09h     endp
;===========================================================================
;============================================================================
int_2Fh proc far
    cmp     AH,0C7h         ; Наш номер?
    jne     Pass_2Fh        ; Нет, на выход
    cmp     AL,00h          ; Подфункция проверки на повторную установку?
    je      inst            ; Программа уже установлена
    cmp     AL,01h          ; Подфункция выгрузки?
    je      unins           ; Да, на выгрузку
    jmp     short Pass_2Fh  ; Неизвестная подфункция - на выход
inst:
    mov     AL,0FFh         ; Сообщим о невозможности повторной установки
    iret
Pass_2Fh:
    jmp dword PTR CS:[int_2Fh_vector]
;
; -------------- Проверка - возможна ли выгрузка программы из памяти ? ------
unins:
    push    BX
    push    CX
    push    DX
    push    ES
;
    mov     CX,CS   ; Пригодится для сравнения, т.к. с CS сравнивать нельзя
    mov     AX,3509h    ; Проверить вектор 09h
    int     21h ; Функция 35h в AL - номер прерывания. Возврат-вектор в ES:BX
;
    mov     DX,ES
    cmp     CX,DX
    jne     Not_remove
;
    cmp     BX, offset CS:new_09h
    jne     Not_remove
;
    mov     AX,352Fh    ; Проверить вектор 2Fh
    int     21h ; Функция 35h в AL - номер прерывания. Возврат-вектор в ES:BX
;
    mov     DX,ES
    cmp     CX,DX
    jne     Not_remove
;
    cmp     BX, offset CS:int_2Fh
    jne     Not_remove
; ---------------------- Выгрузка программы из памяти ---------------------
;
    push    DS
;
    lds     DX, CS:old_09h   ; Эта команда эквивалентна следующим двум
;    mov     DX, word ptr old_09h
;    mov     DS, word ptr old_09h+2
    mov     AX,2509h        ; Заполнение вектора старым содержимым
    int     21h
;
    lds     DX, CS:int_2Fh_vector   ; Эта команда эквивалентна следующим двум
;    mov     DX, word ptr int_2Fh_vector
;    mov     DS, word ptr int_2Fh_vector+2
    mov     AX,252Fh
    int     21h
;
    pop     DS
;
    mov     ES,CS:2Ch       ; ES -> окружение
    mov     AH, 49h         ; Функция освобождения блока памяти
    int     21h
;
    mov     AX, CS
    mov     ES, AX          ; ES -> PSP выгрузим саму программу
    mov     AH, 49h         ; Функция освобождения блока памяти
    int     21h
;
    mov     AL,0Fh          ; Признак успешной выгрузки
    jmp     short pop_ret
Not_remove:
    mov     AL,0F0h          ; Признак - выгружать нельзя
pop_ret:
    pop     ES
    pop     DX
    pop     CX
    pop     BX
;
    iret
int_2Fh endp
;============================================================================
begin:
        mov CL,ES:80h       ; Длина хвоста в PSP
        cmp CL,0            ; Длина хвоста=0?
        je  check_install   ; Да, программа запущена без параметров,
                            ; попробуем установить
        xor CH,CH       ; CX=CL= длина хвоста
        cld             ; DF=0 - флаг направления вперед
        mov DI, 81h     ; ES:DI-> начало хвоста в PSP
        mov SI,offset key   ; DS:SI-> поле key
        mov AL,' '          ; Уберем пробелы из начала хвоста
repe    scasb   ; Сканируем хвост пока пробелы
                ; AL - (ES:DI) -> флаги процессора
                ; повторять пока элементы равны
        dec DI          ; DI-> на первый символ после пробелов
        mov CX, 4       ; ожидаемая длина команды
repe    cmpsb   ; Сравниваем введенный хвост с ожидаемым
                ; (DS:DI)-(ES:DI) -> флаги процессора
        jne check_install ; Неизвестная команда - попробуем установить
        inc flag_off
; Проверим, не установлена ли уже эта программа
check_install:
        mov AX,0C700h   ; AH=0C7h номер процесса C7h
                        ; AL=00h -дать статус установки процесса
        int 2Fh         ; мультиплексное прерывание
        cmp AL,0FFh
        je  already_ins ; возвращает AL=0FFh если установлена
;----------------------------------------------------------------------------
    cmp flag_off,1
    je  xm_stranno
;----------------------------------------------------------------------------
    mov AX,352Fh                      ;   получить
                                      ;   вектор
    int 21h                           ;   прерывания  2Fh
    mov word ptr int_2Fh_vector,BX    ;   ES:BX - вектор
    mov word ptr int_2Fh_vector+2,ES  ;
;
    mov DX,offset int_2Fh           ;   получить смещение точки входа в новый
                                    ;   обработчик на DX
    mov AX,252Fh                    ;   функция установки прерывания
                                    ;   изменить вектор 2Fh
    int 21h  ; AL - номер прерыв. DS:DX - указатель программы обработки прер.
;============================================================================
    mov AX,3509h                        ;   получить
                                        ;   вектор
    int 21h                             ;   прерывания  09h
    mov word ptr old_09h,BX    ;   ES:BX - вектор
    mov word ptr old_09h+2,ES  ;
    mov DX,offset new_09h           ;   получить смещение точки входа в новый
;                                   ;   обработчик на DX
    mov AX,2509h                        ;   функция установки прерывания
                                        ;   изменить вектор 09h
    int 21h ;   AL - номер прерыв. DS:DX - указатель программы обработки прер.
;
        mov DX,offset msg1  ; Сообщение об установке
        call    print
;----------------------------------------------------------------------------
    mov DX,offset   begin           ;   оставить программу ...
    int 27h                         ;   ... резидентной и выйти
;============================================================================
already_ins:
        cmp flag_off,1      ; Запрос на выгрузку установлен?
        je  uninstall       ; Да, на выгрузку
        lea DX,msg          ; Вывод на экран сообщения: already installed!
        call    print
        int 20h
; ------------------ Выгрузка -----------------------------------------------
 uninstall:
        mov AX,0C701h  ; AH=0C7h номер процесса C7h, подфункция 01h-выгрузка
        int 2Fh             ; мультиплексное прерывание
        cmp AL,0F0h
        je  not_sucsess
        cmp AL,0Fh
        jne not_sucsess
        mov DX,offset msg2  ; Сообщение о выгрузке
        call    print
        int 20h
not_sucsess:
        mov DX,offset msg3  ; Сообщение, что выгрузка невозможна
        call    print
        int 20h
xm_stranno:
        mov DX,offset msg4  ; Сообщение, программы нет, а пользователь
        call    print       ; дает команду выгрузки
        int 20h
;----------------------------------------------------------------------------
key         DB  '/off'
flag_off    DB  0
msg         DB  'already '
msg1        DB  'installed',13,10,'$'
msg4        DB  'just '
msg3        DB  'not '
msg2        DB  'uninstalled',13,10,'$'
;============================================================================
PRINT       PROC NEAR
    MOV AH,09H
    INT 21H
    RET
PRINT       ENDP
;;============================================================================
code_seg ends
         end start
