;--------------------------------------------------------------------------
;
;	Officially the FAT type should be determined by calculating the number of clusters
;	needed to address a volume, i.e. devide the total number of sectors by the number
;	of sectors per cluster. If the number is less than 4085 then it is a FAT12 volume
;	if the number is smaller than 65525 then it is a FAT16 else it is a FAT32 volume.
;	Instead of adding a "div" routine I just look at the V_SecPFAT value. If it is
;	not zero then I assume it is a FAT16 volume else it is a FAT32 volume. This does
;	not work for FAT12 volumes, which are _not_ supported here.
;
;	Partition Information. A FAT partition has the following fixed layout:
;
;	VBR		Volumebootrecord
;	reserved	additionally reserved sectors, normally not used for FAT16
;	FAT1		First FAT
;	FAT2		Second FAT, there are typically 2 FATs, never seen something different
;	ROOTDIR		The Root directory (only for FAT16 volumes)
;	DATA		Here start the clusters
;
;	The differences between a FAT16 and FAT32 are very small
;	-	The Root Dir is no longer fixed but an extendable cluster list and
;		the start cluster is noted in the VBR and is stored as normal 
;		directory file in the DATA section of the volume
;	-	A FAT entry for FAT16 has 16 bits and the entry for FAT 32 has 32 bits 
;		of which only 28 bits are used as cluster nbr
;
;	MBR Offsets
;
.equ	M_PartSignature	= 0x1fe
.equ	M_PartTable	= 0x1be		; Start of Partition Table
.equ	M_PartBoot	= 0x00		; Partition Bootable? 0x80:yes, 0x00:no
.equ	M_PartCHSStart	= 0x01		; Start of Partition CHS Format
.equ	M_PartType	= 0x04		; Partition Type
.equ	M_PartLinux	= 0x81		; 
.equ	M_PartCHSSize	= 0x05		; Size of Partition CHS Format
.equ	M_PartStart	= 0x08		; Partition First Sector
.equ	M_PartSize	= 0x0c		; Partition Number of Sectors
.equ	M_PartEntry	= 0x10
;
;	FAT16 and FAT32 VBR offsets 
;
.equ	V_BytesPSect	= 0x00b		; 2 bytes	Bytes Per Sector
.equ	V_SecPClust	= 0x00d		; 1 byte	Sectors Per Cluster
.equ	V_ReservedSect	= 0x00e		; 2 bytes	Reserved Sectors
.equ	V_NumFATs	= 0x010		; 1 byte	Number of FATs
.equ	V_EntriesRootD	= 0x011		; 2 bytes	Number of Entries in Root Directory
.equ	V_OldPartSize	= 0x013		; 2 bytes	Partition Size only valid <32Mbyte
.equ	V_MediaType	= 0x015		; 1 byte	Media Type
.equ	V_SecPFAT	= 0x016		; 2 bytes	Sectors Per FAT (FAT16) or 0 (FAT32)
.equ	V_SecPTrack	= 0x018		; 2 bytes	Sectors Per Track
.equ	V_NumHeads	= 0x01a		; 2 bytes	Number of Heads
.equ	V_PartStart	= 0x01c		; 4 bytes	Partition Start Sector
.equ	V_PartSize	= 0x020		; 4 bytes	Partition Size in Sectors
;
;	FAT16 specific
;
.equ	V_FAT16Label	= 0x02b		;11 bytes	FAT-16 Partition Label
;
;	FAT32 specific
;
.equ	V_SecPFAT32	= 0x024		; 4 bytes	Sectors Per FAT32
.equ	V_FAT32Status	= 0x028		; 2 bytes	FAT-Bitschalter
.equ	V_FAT32Version	= 0x02a		; 2 bytes	FAT32 Version
.equ	V_FAT32RootClus	= 0x02c		; 4 bytes	Start Cluster of Root Directory
.equ	V_FAT32Label	= 0x047		;11 bytes	FAT-32 Parition Label
;
;	Directory Entry
;
.equ	D_Name		= 0x00
.equ	D_Ext		= 0x08
.equ	D_Attr		= 0x0b
.equ	D_Reserved	= 0x0c		; OS specific
.equ	D_ClusterH	= 0x14		; High word of start cluster for FAT32
.equ	D_Time		= 0x16
.equ	D_Date		= 0x18
.equ	D_Cluster	= 0x1a		; (Low) word of start cluster
.equ	D_Size		= 0x1c
;
;	Directory Entry Attributes
;
.equ	A_Long		= 0x0f		; If the value of D_Attr == A_Long the entry is part of the long file name
.equ	A_Readonly	= 0		; File is write protected
.equ	A_Hidden	= 1		; File is hidden
.equ	A_System	= 2		; File is a system component
.equ	A_Volume	= 3		; Directory entry is a volume name
.equ	A_Directory	= 4		; File is a directory
.equ	A_Archive	= 5		; The file has been archived

#define FAT_OK 0		// Success
#define FAT_EOF 255		// End Of File
#define FAT_INS 254		// Insufficient Memory
#define FAT_MAG 253		// No MAGIC Number 0x55aa found
#define FAT_OFL 252		// Offline
#define FAT_FDE 251		// Free Directory Entry
#define FAT_FNF 250		// File Not Found
#define FAT_NAD 249		// Not a Directory
#define FAT_NAF 248		// Not a File
#define FAT_OPE 247		// File Open Error
#define FAT_RDE 246		// Read Error


