[ORG 0x00]				; 코드의 시작 어드레스를 0x00으로 설정
[BITS 16]				; 이하의 코드는 16비트 코드로 설정

SECTION .text			; text 섹션(세그먼트)을 정의

jmp 0x07C0:START		; CS 세그먼트 레지스터에 0x07C0을 복사하면서, START 레이블로 이동

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;		MINT64 OS에 관련된 환경 설정 값
TOTALSECTORCOUNT: dw 1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



START:
	mov ax, 0x07C0	; 부트 로더의 시작 어드레스(0x7C00)를 세그먼트 레지스터 값으로 변환
	mov ds, ax			; DS 세그먼트 레지스터에 설정
	mov ax, 0xB800	; 비디오 메모리의 시작 어드레스(0xB800)를 세그먼트 레지스터 값으로 변환
	mov es, ax			; ES 세그먼트 레지스터에 설정

	mov ax, 0x0000
	mov ss, ax
	mov sp, 0xFFFE
	mov bp, 0xFFFE

	mov si,	0		; SI 레지스터(문자열 원본 인덱스 레지스터)를 초기화

.SCREENCLEARLOOP:						; 화면을 지우는 루프
	mov byte [ es: si ], 0			; 비디오 메모리의 문자가 위치하는 어드레스에 0을 복사하여 문자를 삭제

	mov byte [ es: si + 1 ], 0x0A	; 비디오 메모리의 속성이 위치하는 어드레스에 0X0A(검은 바탕에 밝은 녹색)을 복사

	add si, 2							; 문자의 속성을 설정했으므로 다음 위치로 이동

	cmp si, 80 * 25 * 2	; 화면의 전체 크기는 80 문자 * 25 라인
							; 출력한 문자의 수를 의미하는 SI 레지스터와 비교
	jl .SCREENCLEARLOOP	; SI 레지스터가 80 * 25 * 2보다 작다면 아직 지우지 못한
							; 영역이 있으므로 .SCREENCLEARLOOP 레이블로 이동

	push MESSAGE1
	push 0
	push 0
	call PRINTMESSAGE
	add sp, 6

	push IMAGELOADINGMESSAGE
	push 1
	push 0
	call PRINTMESSAGE
	add sp, 6

RESETDISK:
	mov ax, 0
	mov dl, 0
	int 0x13
	jc HANDLEDISKERROR

	mov si, 0x1000
	mov es, si
	mov bx, 0x0000


	mov di, word [ TOTALSECTORCOUNT ]

READDATA:

	cmp di, 0
	je READEND
	sub di, 0x1

	mov ah, 0x02
	mov al, 0x1
	mov ch, byte [ TRACKNUMBER ]
	mov cl, byte [ SECTORNUMBER ]
	mov dh, byte [ HEADNUMBER ]
	mov dl, 0x00
	int 0x13
	jc HANDLEDISKERROR

	add si, 0x0020
	mov es, si

	mov al, byte [ SECTORNUMBER ]
	add al, 0x01
	mov byte [ SECTORNUMBER ], al
	cmp al, 19
	jl READDATA

	xor byte [ HEADNUMBER ], 0x01
	mov byte [ SECTORNUMBER ], 0x01

	cmp byte [ HEADNUMBER ] , 0x00
	jne READDATA

	add byte [ TRACKNUMBER ], 0x01
	jmp READDATA

READEND:
	push LOADINGCOMPLETEMESSAGE
	push 1
	push 20
	call PRINTMESSAGE
	add sp, 6

	jmp 0x1000:0x0000

HANDLEDISKERROR:
	push DISKERRORMESSAGE
	push 1
	push 20
	call PRINTMESSAGE

	jmp $

PRINTMESSAGE:
	push bp
	mov bp, sp

	push es
	push si
	push di
	push ax
	push cx
	push dx

	mov ax, 0xB800
	mov es, ax

	mov ax, word [ bp + 6 ]
	mov si, 160
	mul si
	mov di, ax

	mov ax, word [ bp + 4 ]
	mov si, 2
	mul si
	add di, ax

	mov si, word [ bp + 8 ]

.MESSAGELOOP:							; 메시지를 출력하는 루프
	mov cl, byte [ si ]	; MESSAGE1의 어드레스에서 SI 레지스터 값만큼
										; 더한 위치의 문자를 CL 레지스터에 복사
										; CL 레지스터는 CX 레지스터의 하위 1바이트를 의미
										; 문자열은 1바이트면 충분하므로 CX 레지스터의 하위 1바이트만 사용

	cmp cl, 0					; 복사된 문자와 0을 비교
	je .MESSAGEEND			; 복사한 문자의 값이 0이면 문자열이 종료되었음을
								; 의미하므로 . MESSAGEEND로 이동하여 문자 출력 종료
	mov byte [ es: di ], cl	; 0이 아니라면 비디오 메모리 어드레스 0xB800:di에 문자를 출력

	add si, 1					; SI 레지스터에 1을 더하여 다음 문자열로 이동
	add di, 2					; DI 레지스터에 2를 더하여 비디오 메모리의 다음 문자 위치로 이동
								; 비디오 메모리는 (문자, 속성)의 쌍으로 구성되므로 문자만 출력하려면
								; 2를 더해야함

	jmp .MESSAGELOOP			; 메세지 출력 루프로 이동하여 다음 문자를 출력

.MESSAGEEND:
	pop dx
	pop cx
	pop ax
	pop di
	pop si
	pop es
	pop bp
	ret

MESSAGE1:	db 'MINT64 OS BOOT Loader Start~!!', 0 ; 출력할 메시지 정의

DISKERRORMESSAGE:				db 'DISK ERROR~!!', 0
IMAGELOADINGMESSAGE: 		db 'OS Image Loading...', 0
LOADINGCOMPLETEMESSAGE:		db 'Complete~!!', 0

SECTORNUMBER:		db 0x02
HEADNUMBER:		db 0x00
TRACKNUMBER: 		db 0x00

times 510 - ( $ - $$ )	db	0x00	; $: 현재 라인의 어드레스
										; $$: 현재 섹션(.text)의 시작 어드레스
										; $ - $$: 현재 섹션을 기준으로 하는 오프셋
										; 510 - ( $ - $$ ): 현재부터 어드레스 510까지
										; db 0x00: 1바이트를 선언하고 값은 0x00
										; time: 반복수행
										; 현재 위치에서 어드레스 510까지 0x00으로 채움

db 0x55				; 1바이트를 선언하고 값은 0x55
db 0xAA				; 1바이트를 선언하고 값은 0xAA
						; 어드레스 511, 512에 0x55, 0xaa를 써서 부트 섹터로 표기함
